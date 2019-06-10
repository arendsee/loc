{-# LANGUAGE OverloadedStrings, TemplateHaskell, QuasiQuotes #-}

{-|
Module      : C
Description : Build a C program given a file
Copyright   : (c) Zebulun Arendsee, 2019
License     : GPL-3
Maintainer  : zbwrnz@gmail.com
Stability   : totally experimental

The build process for C differs from that used in R and python since a
compilation step is needed. This code currently is wildly experimental.
-}

module Morloc.Pools.Template.C
( 
  generate
) where

import Morloc.Global
import Morloc.Manifold as Man
import qualified Morloc.Data.Text as MT
import qualified Morloc.Component.Serializer as Serializer
import qualified Morloc.Component.Manifold as Manifold
import qualified Morloc.Monad as MM
import Morloc.Data.Doc hiding ((<$>))
import Morloc.Quasi
import Morloc.Pools.Common
import qualified Data.Map.Strict as Map

type CType = Doc
type CVar = Doc
type CVal = Doc
type CExpr = Doc
type CStatement = Doc

-- | this must contain all the information needed to build a C program
data CGlobal = CProg {
    includesC :: [Doc] -- ^ list of include statements
  , globalC :: [Doc] -- ^ any global variables
  , functionsC :: [CFunction] -- ^ list of functions and their type info
  , allocatedC :: [CVar] -- ^ things to free when leaving main
  , mainC :: Doc
}

data CFunction = CFunction {
    cFReturnType :: Doc -- ^ return type
  , cFName :: Doc -- ^ function name
  , cFArgs :: [(CType, CVar)]
  , cFBody :: Doc 
}

generate :: SparqlDatabaseLike db => db -> MorlocMonad Script
generate db = pure Script <*> pure "pool" <*> pure CLang <*> generateC db

generateC :: SparqlDatabaseLike db => db -> MorlocMonad MT.Text
generateC db = do
  manifolds <- Manifold.fromSparqlDb db                 -- [Manifold]
  packMap <- Serializer.fromSparqlDb CLang db           -- SerialMap
  paksrcs <- mapM nameSource (serialSources packMap)    -- [Doc]
  mansrcs <- Man.getManSrcs CLang nameSource manifolds  -- [Doc]
  usedManifolds <- Man.getUsedManifolds CLang manifolds -- [Manifold]
  simpleManifolds <- mapM (\m -> makeCFunction m >>= makeFunctionDoc) $ usedManifolds
  dispatch' <- makeDispatch packMap usedManifolds
  let sources' = makeSources (mansrcs ++ paksrcs) <> line
  fmap render $ main sources' (vsep simpleManifolds) dispatch'
  where
    nameSource :: MT.Text -> MorlocMonad Doc
    nameSource = return . dquotes . text'

makeFunctionDoc :: CFunction -> MorlocMonad Doc
makeFunctionDoc f = do
  let targs = tupled (map (\(t, x) -> t <+> x) (cFArgs f))
  let rargs = tupled (map snd (cFArgs f))
  let head = [idoc|#{cFReturnType f} #{cFName f}#{targs}|]
  return $ head <> blockC (cFBody f)

makeCFunction :: Manifold -> MorlocMonad CFunction
makeCFunction m = do
  returnType <- getReturnType m
  argTypes <- getArgTypes m
  body <- makeBody m
  return $ CFunction {
      cFReturnType = returnType
    , cFName = makeFunctionName m
    , cFArgs = zip (argTypes) (map (\i -> "x" <> integer i) [0..])
    , cFBody = body
  }

makeFunctionName :: Manifold -> Doc
makeFunctionName m = "m" <> integer (mid m)

makeBody :: Manifold -> MorlocMonad Doc
makeBody m = return
  $   "return"
  <+> callC (text' $ mCallName m)
            (zipWith (\i _ -> "x" <> integer i) [0..] (mArgs m))
  <> ";"

getReturnType :: Manifold -> MorlocMonad Doc
getReturnType m = case mConcreteType m of
  (Just (MFuncType _ _ rtype)) -> toCType rtype
  (Just t) -> MM.throwError . TypeError $ "Expected function type, got: " <> MT.show' t
  Nothing -> MM.throwError . TypeError $ "Missing return type: " <> MT.show' m

getArgTypes :: Manifold -> MorlocMonad [Doc]
getArgTypes m = case mConcreteType m of 
  (Just (MFuncType _ argTypes _)) -> mapM toCType argTypes
  (Just t) -> MM.throwError . TypeError $ "Expected function type, got: " <> MT.show' t
  Nothing -> MM.throwError . TypeError $ "Missing concrete type: " <> MT.show' m

makeSources :: [Doc] -> Doc
makeSources = vsep . map ((<+>) "#include")

initializeC :: CType -> CVar -> CExpr
initializeC t v = t <+> v <> ";"

assign :: Maybe CType -> CVar -> CVal -> Doc
assign Nothing v x = v <+> "=" <+> x <> ";"
assign (Just t) v x = t <+> v <+> "=" <+> x <> ";"

callC :: CVar -> [CExpr] -> CExpr
callC f args = f <> tupled args

callC' :: CVar -> CExpr -> CExpr
callC' f arg = callC f [arg]

blockC :: CStatement -> Doc
blockC x = "{" <> line <> "  " <> indent 2 x <> line <> "}"

-- FIXME: this is all a dirty hack. The type strings for a given language MUST
-- NOT be specified in the Haskell code. You should be able to implement
-- handling for a language without having to touch the Haskell core. In the
-- dynamic languages (R and Python), the problem is easier because I don't have
-- to explicitly state the data types.
-- FIXME: I should require 'MTypeMeta{metaLang = Just CLang}'
toCType :: MType -> MorlocMonad Doc
toCType (MConcType _ "Double" []) = return "double"
toCType (MConcType _ "String" []) = return "char*"
toCType (MConcType _ "Int"    []) = return "int"
toCType t = MM.throwError . TypeError $ "Unknown C type: " <> MT.show' t

-- | Generate a switch statement
switchC
  :: CVar
  -- ^ The variable the switch statement dispatches upon
  -> [(CVal, CStatement)]
  -- ^ Pairs of values and statements to put in the block (@break@ will automatically be added)
  -> CStatement
  -- ^ Statements that go in the @default@ block
  -> Doc
switchC x cases def = callC' "switch" x <> blockC caseBlock where
  caseBlock = vsep (map asCase cases) <> line <> def'
  asCase (v, body) = ("case" <+> v <> ":") <> line <> (indent 2 $ caseC body)
  def' = "default:" <> line <> indent 2 def

caseC :: Doc -> Doc
caseC body = body <> line <> "break;"

-- // e.g., create something like this:
-- switch(mid){
--     case 1:
--         json = packDouble(m0(unpackDouble(argv[2])));
--         break;
--     case 2:
--         json = packDouble(m1(unpackDouble(argv[2])));
--         break;
--     default:
--         break;
-- }
makeDispatch :: SerialMap -> [Manifold] -> MorlocMonad Doc
makeDispatch h ms =
  switchC
    <$> pure "mid"  -- the integer manifold id (initialized in the main template)
    <*> mapM (makeManifoldCase h) ms  -- case for dispatching to each manifold
    <*> pure "return 1;"  -- default case, TODO: make a proper error message

makeManifoldCase :: SerialMap -> Manifold -> MorlocMonad (Doc, Doc)
makeManifoldCase h m = do
  unpackers <- getUnpackers h m
  let packer = getPacker h m
  let f = makeFunctionName m
  let caseVar = integer (mid m)
  let call = callC f (zipWith callC'
                              unpackers
                              (map (\i -> "argv[" <> integer i <> "]") [2..]))
  let caseBody = assign Nothing "json" (callC' packer call)
  return (caseVar, caseBody)

-- | Single line comment
commentC :: Doc -> Doc
commentC x = enclose "/*" "*/" x

-- | Multi-line comment
multicommentC :: Doc -> Doc
multicommentC x = enclose "/*" "*/" (nest 2 x)

-- | Create if else
conditionalC :: [(Doc, Doc)] -> Maybe Doc -> Doc
conditionalC [] (Just _) = error "else without if"
conditionalC ((c, b):xs) els = callC' "if" c <> blockC b <> conditionalC' xs els where
  conditionalC' [] Nothing = ""
  conditionalC' [] (Just x) = "else" <> blockC x
  conditionalC' ((c', b'):xs) els
    =   callC' "else if" c' <> blockC b' 
    <> line <> conditionalC' xs els

-- | Create the prototype of a function
prototypeC :: CFunction -> Doc
prototypeC r =  (cFReturnType r) <+> (cFName r)
             <> encloseSep "(" ")" "," (map (\(t, v) -> t <+> v) (cFArgs r))

-- | Create a function
functionC :: CFunction -> Doc
functionC r = prototypeC r <> enclose "{" "}" (indent 2 (cFBody r))

main :: Doc -> Doc -> Doc -> MorlocMonad Doc
main sources cismanifolds switch = do
  return [idoc|
#include <string.h>

#include <stdio.h>

#{sources}

#{cismanifolds}

int main(int argc, char * argv[]){
  int mid;
  char* json;
  mid = atoi(argv[1]);
  #{switch}
  printf("%s\n", json);
  return 0;
}
|]
