{-# LANGUAGE TemplateHaskell, QuasiQuotes #-}

module Morloc.Quasi (idoc) where

import Language.Haskell.TH
import Language.Haskell.TH.Quote
import qualified Morloc.Data.Doc as Gen
import qualified Morloc.Data.Text as MT

import qualified Language.Haskell.Meta.Parse as MP

import Text.Parsec

type Parser = Parsec String ()

data I = S String | V String

pIs :: Parser [I]
pIs = many1 (try pV <|> pS <|> pE) <* eof

pV :: Parser I
pV = fmap V $ between (string "${") (char '}') (many1 (noneOf "}")) 

pS :: Parser I
pS = fmap S $ many1 (noneOf "$")

-- | match a literal '$' sign
pE :: Parser I
pE = fmap (S . return) $ char '$' <* notFollowedBy (char '}')


-- | __i__nterpolated __doc__ument
idoc :: QuasiQuoter
idoc = QuasiQuoter {
    quoteExp  = compile
  , quotePat  = error "Can't handle patterns"
  , quoteType = error "Can't handle types"
  , quoteDec  = error "Can't handle declarations"
  }
  where
    compile :: String -> Q Exp
    compile txt = case parse pIs "" txt of
      Left err -> error $ show err
      Right xs -> return $ AppE (VarE 'Gen.hcat) (ListE (map qI xs)) where
        qI :: I -> Exp
        qI (S x) = AppE (VarE 'Gen.string) (LitE (StringL x))
        qI (V x) = case MP.parseExp x of
          (Right hask) -> hask -- a Haskell expression
          (Left err) -> error err
