{-# LANGUAGE TemplateHaskell, QuasiQuotes #-}

{-|
Module      : Morloc.CodeGenerator.Grammars.Translator.R
Description : R translator
Copyright   : (c) Zebulun Arendsee, 2020
License     : GPL-3
Maintainer  : zbwrnz@gmail.com
Stability   : experimental
-}

module Morloc.CodeGenerator.Grammars.Translator.R
  ( 
    translate
  ) where

import Morloc.Namespace
import Morloc.CodeGenerator.Grammars.Common
import Morloc.Data.Doc
import Morloc.Quasi
import qualified Morloc.Data.Text as MT


translate :: [Source] -> [CallTree] -> MorlocMonad MDoc
translate srcs mss = do 
  let includes = unique . catMaybes . map srcPath $ srcs
  includeDocs <- mapM translateSource includes
  mss' <- mapM serializeCallTree mss

  say $ (vsep $ map prettyCallTree mss')

  mDocs <- mapM translateManifold (concat [m:ms | (CallTree m ms) <- mss'])
  return $ makeMain includeDocs mDocs

serialType :: CType
serialType = CType (VarT (TV (Just RLang) "character"))

typeSchema :: CType -> MDoc
typeSchema c = f (unCType c)
  where
    f (VarT v) = dquotes (var v)
    f (ArrT v ps) = lst [var v <> "=" <> lst (map f ps)]
    f (NamT v es) = lst [var v <> "=" <> lst (map entry es)]
    f t = error $ "Cannot serialize this type: " <> show t

    entry :: (MT.Text, Type) -> MDoc
    entry (v, t) = pretty v <> "=" <> f t

    lst :: [MDoc] -> MDoc
    lst xs = "list" <> encloseSep "(" ")" "," xs

    var :: TVar -> MDoc
    var (TV _ v) = pretty v

translateSource :: Path -> MorlocMonad MDoc
translateSource p = return $ "source(" <> dquotes (pretty p) <> ")"

translateManifold :: Manifold -> MorlocMonad MDoc
translateManifold (Manifold v args es) = do
  let head = returnName v <+> "<- function" <> tupled (map makeArgument args)
  body <- mapM (translateExpr args) es |>> vsep
  return $ line <> block 4 head body

translateExpr :: [Argument] -> ExprM -> MorlocMonad MDoc
translateExpr args (AssignM v e) = do
  e' <- translateExpr args e
  return $ pretty v <+> "<-" <+> e'
translateExpr args (SrcCallM _ (VarM _ v) es) = do
  xs <- mapM (translateExpr args) es
  return $ pretty v <> tupled xs
translateExpr args (ManCallM _ i es) = do
  xs <- mapM (translateExpr args) es
  return $ "m" <> pretty i <> tupled xs
translateExpr args (ForeignCallM _ i lang vs) = return "FOREIGN"
translateExpr args (ReturnM e) = translateExpr args e
translateExpr args (VarM _ v) = return $ pretty v
translateExpr args (ListM _ es) = do
  xs <- mapM (translateExpr args) es
  return $ "c" <> tupled xs
translateExpr args (TupleM _ es) = do
  xs <- mapM (translateExpr args) es
  return $ "list" <> tupled xs
translateExpr args (RecordM _ entries) = do
  xs' <- mapM (translateExpr args . snd) entries
  let entries' = zipWith (\k v -> pretty k <> "=" <> v) (map fst entries) xs'
  return $ "list" <> tupled entries'
translateExpr args (LogM _ x) = return $ if x then "TRUE" else "FALSE"
translateExpr args (NumM _ x) = return $ viaShow x
translateExpr args (StrM _ x) = return $ dquotes (pretty x)
translateExpr args (NullM _) = return "NULL"
translateExpr args (PackM e) = do
  e' <- translateExpr args e
  let c = typeOfExprM e
      schema = typeSchema c
  return $ "pack" <> tupled [e', schema]
translateExpr args (UnpackM e) = do
  e' <- translateExpr args e
  let c = typeOfExprM e
      schema = typeSchema c
  return $ "unpack" <> tupled [e', schema]

makeArgument :: Argument -> MDoc
makeArgument (PackedArgument v c) = pretty v
makeArgument (UnpackedArgument v c) = pretty v
makeArgument (PassThroughArgument v) = pretty v

returnName :: ReturnValue -> MDoc
returnName (PackedReturn v _) = "m" <> pretty v
returnName (UnpackedReturn v _) = "m" <> pretty v
returnName (PassThroughReturn v) = "m" <> pretty v

say :: Doc ann -> MorlocMonad ()
say = liftIO . putDoc

makeMain :: [MDoc] -> [MDoc] -> MDoc
makeMain sources manifolds = [idoc|#!/usr/bin/env Rscript

#{vsep sources}

.morloc_run <- function(f, args){
  fails <- ""
  isOK <- TRUE
  warns <- list()
  notes <- capture.output(
    {
      value <- withCallingHandlers(
        tryCatch(
          do.call(f, args),
          error = function(e) {
            fails <<- e$message;
            isOK <<- FALSE
          }
        ),
        warning = function(w){
          warns <<- append(warns, w$message)
          invokeRestart("muffleWarning")
        }
      )
    },
    type="message"
  )
  list(
    value = value,
    isOK  = isOK,
    fails = fails,
    warns = warns,
    notes = notes
  )
}

# dies on error, ignores warnings and messages
.morloc_try <- function(f, args, .log=stderr(), .pool="_", .name="_"){
  x <- .morloc_run(f=f, args=args)
  location <- sprintf("%s::%s", .pool, .name)
  if(! x$isOK){
    cat("** R errors in ", location, "\n", file=stderr())
    cat(x$fails, "\n", file=stderr())
    stop(1)
  }
  if(! is.null(.log)){
    lines = c()
    if(length(x$warns) > 0){
      cat("** R warnings in ", location, "\n", file=stderr())
      cat(paste(unlist(x$warns), sep="\n"), file=stderr())
    }
    if(length(x$notes) > 0){
      cat("** R messages in ", location, "\n", file=stderr())
      cat(paste(unlist(x$notes), sep="\n"), file=stderr())
    }
  }
  x$value
}

.morloc_unpack <- function(unpacker, x, .pool, .name){
  x <- .morloc_try(f=unpacker, args=list(as.character(x)), .pool=.pool, .name=.name)
  return(x)
}

.morloc_foreign_call <- function(cmd, args, .pool, .name){
  .morloc_try(f=system2, args=list(cmd, args=args, stdout=TRUE), .pool=.pool, .name=.name)
}

#{vsep manifolds}

args <- as.list(commandArgs(trailingOnly=TRUE))
if(length(args) == 0){
  stop("Expected 1 or more arguments")
} else {
  cmdID <- args[[1]]
  f_str <- paste0("m", cmdID)
  if(exists(f_str)){
    f <- eval(parse(text=paste0("m", cmdID)))
    result <- do.call(f, args[-1])
    cat(result, "\n")
  } else {
    cat("Could not find manifold '", cmdID, "'\n", file=stderr())
  }
}
|]
