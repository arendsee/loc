{-|
Module      : Morloc.Pretty
Description : Pretty print instances
Copyright   : (c) Zebulun Arendsee, 2019
License     : GPL-3
Maintainer  : zbwrnz@gmail.com
Stability   : experimental
-}
module Morloc.Pretty
  ( prettyExpr
  , prettyModule
  , prettyType
  ) where

import Data.Text.Prettyprint.Doc.Render.Terminal
import Morloc.Data.Doc
import Morloc.Namespace
import qualified Data.Set as Set
import qualified Data.Text.Prettyprint.Doc.Render.Terminal.Internal as Style

instance Pretty MType where
  pretty (MConcType _ n []) = pretty n
  pretty (MConcType _ n ts) = parens $ hsep (pretty n : (map pretty ts))
  pretty (MAbstType _ n []) = pretty n
  pretty (MAbstType _ n ts) = parens $ hsep (pretty n : (map pretty ts))
  pretty (MFuncType _ ts o) =
    parens $ (hcat . punctuate ", ") (map pretty ts) <> " -> " <> pretty o

instance Pretty MVar where
  pretty (MV t) = pretty t

instance Pretty EVar where
  pretty (EV t) = pretty t

instance Pretty TVar where
  pretty (TV Nothing t) = pretty t
  pretty (TV (Just lang) t) = pretty t <> "@" <> pretty (show lang)

typeStyle =
  Style.SetAnsiStyle
    { Style.ansiForeground = Just (Vivid, Green)
    , Style.ansiBackground = Nothing
    , Style.ansiBold = Nothing
    , Style.ansiItalics = Nothing
    , Style.ansiUnderlining = Just Underlined
    }

prettyMVar :: MVar -> Doc AnsiStyle
prettyMVar (MV x) = pretty x

prettyModule :: Module -> Doc AnsiStyle
prettyModule m =
  prettyMVar (moduleName m) <+>
  braces (line <> (indent 4 (prettyBlock m)) <> line)

prettyBlock :: Module -> Doc AnsiStyle
prettyBlock m =
  vsep (map prettyImport (moduleImports m)) <>
  vsep ["export" <+> pretty e <> line | (EV e) <- moduleExports m] <>
  vsep (map prettyExpr (moduleBody m))

prettyImport :: Import -> Doc AnsiStyle
prettyImport imp =
  "import" <+>
  pretty (importModuleName imp) <+>
  maybe
    "*"
    (\xs -> encloseSep "(" ")" ", " (map prettyImportOne xs))
    (importInclude imp)
  where
    prettyImportOne (EV e, EV alias)
      | e /= alias = pretty e
      | otherwise = pretty e <+> "as" <+> pretty alias

prettyConcrete :: (Maybe Lang) -> Doc a
prettyConcrete Nothing = ""
prettyConcrete (Just l) = angles (viaShow l)

prettyExpr :: Expr -> Doc AnsiStyle
prettyExpr UniE = "()"
prettyExpr (VarE (EV s)) = pretty s
prettyExpr (LamE (EV n) e) = "\\" <> pretty n <+> "->" <+> prettyExpr e
prettyExpr (AnnE e ts) = parens
  $   prettyExpr e
  <+> "::"
  <+> encloseSep "(" ")" "; " [prettyGreenType t <> prettyConcrete l | (l, t) <- ts]
prettyExpr (AppE e1@(LamE _ _) e2) = parens (prettyExpr e1) <+> prettyExpr e2
prettyExpr (AppE e1 e2) = prettyExpr e1 <+> prettyExpr e2
prettyExpr (NumE x) = pretty (show x)
prettyExpr (StrE x) = dquotes (pretty x)
prettyExpr (LogE x) = pretty x
prettyExpr (Declaration (EV v) e) = pretty v <+> "=" <+> prettyExpr e
prettyExpr (ListE xs) = list (map prettyExpr xs)
prettyExpr (TupleE xs) = tupled (map prettyExpr xs)
prettyExpr (SrcE lang (Just f) rs) =
  "source" <+>
  viaShow lang <+>
  "from" <+>
  pretty f <+>
  tupled
    (map
       (\(EV n, EV a) ->
          pretty n <>
          if n == a
            then ""
            else (" as" <> pretty a))
       rs)
prettyExpr (SrcE lang Nothing rs) =
  "source" <+>
  viaShow lang <+>
  tupled
    (map
       (\(EV n, EV a) ->
          pretty n <>
          if n == a
            then ""
            else (" as" <> pretty a))
       rs)
prettyExpr (RecE entries) =
  encloseSep
    "{"
    "}"
    ", "
    (map (\(EV v, e) -> pretty v <+> "=" <+> prettyExpr e) entries)
prettyExpr (Signature (EV v) e) =
  pretty v <+> elang' <> "::" <+> eprop' <> etype' <> econs'
  where
    elang' :: Doc AnsiStyle
    elang' = maybe "" (\lang -> viaShow lang <> " ") (elang e)
    eprop' :: Doc AnsiStyle
    eprop' =
      case Set.toList (eprop e) of
        [] -> ""
        xs -> tupled (map prettyProperty xs) <+> "=> "
    etype' :: Doc AnsiStyle
    etype' = prettyGreenType (etype e)
    econs' :: Doc AnsiStyle
    econs' =
      case Set.toList (econs e) of
        [] -> ""
        xs -> " where" <+> tupled (map (\(Con x) -> pretty x) xs)

prettyProperty :: Property -> Doc ann
prettyProperty Pack = "pack"
prettyProperty Unpack = "unpack"
prettyProperty Cast = "cast"
prettyProperty (GeneralProperty ts) = hsep (map pretty ts)

forallVars :: Type -> [Doc a]
forallVars (Forall v t) = pretty v : forallVars t
forallVars _ = []

forallBlock :: Type -> Doc a
forallBlock (Forall _ t) = forallBlock t
forallBlock t = prettyType t

prettyGreenType :: Type -> Doc AnsiStyle
prettyGreenType t = annotate typeStyle (prettyType t)

prettyType :: Type -> Doc ann
prettyType UniT = "1"
prettyType (VarT v) = pretty v
prettyType (FunT t1@(FunT _ _) t2) =
  parens (prettyType t1) <+> "->" <+> prettyType t2
prettyType (FunT t1 t2) = prettyType t1 <+> "->" <+> prettyType t2
prettyType t@(Forall _ _) =
  "forall" <+> hsep (forallVars t) <+> "." <+> forallBlock t
prettyType (ExistT v) = angles (pretty v)
prettyType (ArrT v ts) = pretty v <+> hsep (map prettyType ts)
prettyType (RecT entries) =
  encloseSep "{" "}" ", "
    (map (\(v, e) -> pretty v <+> "=" <+> prettyType e) entries)
