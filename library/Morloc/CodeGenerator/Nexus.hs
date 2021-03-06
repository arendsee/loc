{-# LANGUAGE TemplateHaskell, QuasiQuotes #-}

{-|
Module      : Morloc.CodeGenerator.Nexus
Description : Templates for generating a Perl nexus
Copyright   : (c) Zebulun Arendsee, 2021
License     : GPL-3
Maintainer  : zbwrnz@gmail.com
Stability   : experimental
-}
module Morloc.CodeGenerator.Nexus
  ( generate
  ) where

import Morloc.Data.Doc
import Morloc.CodeGenerator.Namespace
import Morloc.Quasi
import Morloc.Pretty (prettyType)
import qualified Morloc.Data.Text as MT
import qualified Control.Monad as CM
import qualified Morloc.Config as MC
import qualified Morloc.Language as ML
import qualified Morloc.Monad as MM

type FData =
  ( MDoc -- pool call command, (e.g., "RScript pool.R 4 --")
  , MDoc -- subcommand name
  , TypeP -- argument type
  )

generate :: [NexusCommand] -> [(TypeP, Int, Maybe EVar)] -> MorlocMonad Script
generate cs xs = do
  let names = [pretty name | (_, _, Just name) <- xs] ++ map (pretty . commandName) cs
  fdata <- CM.mapM getFData [(t, i, n) | (t, i, Just n) <- xs] -- [FData]
  return $
    Script
      { scriptBase = "nexus"
      , scriptLang = ML.PerlLang
      , scriptCode = Code . render $ main names fdata cs
      , scriptCompilerFlags = []
      , scriptInclude = []
      }

getFData :: (TypeP, Int, EVar) -> MorlocMonad FData
getFData (t, i, n) = do
  config <- MM.ask
  let lang = langOf t
  case MC.buildPoolCallBase config lang i of
    (Just cmds) -> return (hsep cmds, pretty n, t)
    Nothing ->
      MM.throwError . GeneratorError $
      "No execution method found for language: " <> ML.showLangName (fromJust lang)

main :: [MDoc] -> [FData] -> [NexusCommand] -> MDoc
main names fdata cdata =
  [idoc|#!/usr/bin/env perl

use strict;
use warnings;

use JSON::XS;

my $json = JSON::XS->new->canonical;

&printResult(&dispatch(@ARGV));

sub printResult {
    my $result = shift;
    print "$result";
}

sub dispatch {
    if(scalar(@_) == 0){
        &usage();
    }

    my $cmd = shift;
    my $result = undef;

    #{mapT names}

    if($cmd eq '-h' || $cmd eq '-?' || $cmd eq '--help' || $cmd eq '?'){
        &usage();
    }

    if(exists($cmds{$cmd})){
        $result = $cmds{$cmd}(@_);
    } else {
        print STDERR "Command '$cmd' not found\n";
        &usage();
    }

    return $result;
}

#{usageT fdata cdata}

#{vsep (map functionCT cdata ++ map functionT fdata)}

|]

mapT names = [idoc|my %cmds = #{tupled (map mapEntryT names)};|]

mapEntryT n = [idoc|#{n} => \&call_#{n}|]

usageT :: [FData] -> [NexusCommand] -> MDoc
usageT fdata cdata =
  [idoc|
sub usage{
    print STDERR "The following commands are exported:\n";
    #{align $ vsep (map usageLineT fdata ++ map usageLineConst cdata)}
    exit 0;
}
|]

usageLineT :: FData -> MDoc
usageLineT (_, name, t) = vsep
  ( [idoc|print STDERR "  #{name}\n";|]
  : writeTypes (gtypeOf t)
  )

gtypeOf (UnkP (PV _ (Just v) _)) = UnkT (TV Nothing v)
gtypeOf (VarP (PV _ (Just v) _)) = VarT (TV Nothing v)
gtypeOf (FunP t1 t2) = FunT (gtypeOf t1) (gtypeOf t2)
gtypeOf (ArrP (PV _ (Just v) _) ts) = ArrT (TV Nothing v) (map gtypeOf ts)
gtypeOf (NamP r (PV _ (Just v) _) ps es)
  = NamT r (TV Nothing v)
           (map gtypeOf ps)
           (zip [k | (PV _ (Just k) _, _) <- es] (map (gtypeOf . snd) es))
gtypeOf _ = UnkT (TV Nothing "?") -- this shouldn't happen

usageLineConst :: NexusCommand -> MDoc
usageLineConst cmd = vsep
  ( [idoc|print STDERR "  #{pretty (commandName cmd)}\n";|]
  : writeTypes (commandType cmd) 
  )

writeTypes :: Type -> [MDoc]
writeTypes t =
  let (inputs, output) = decompose t
  in zipWith writeType [Just i | i <- [1..]] inputs ++ [writeType Nothing output]

writeType :: Maybe Int -> Type -> MDoc
writeType (Just i) t  = [idoc|print STDERR q{    param #{pretty i}: #{prettyType t}}, "\n";|]
writeType (Nothing) t = [idoc|print STDERR q{    return: #{prettyType t}}, "\n";|]


functionT :: FData -> MDoc
functionT (cmd, name, t) =
  [idoc|
sub call_#{name}{
    if(scalar(@_) != #{pretty n}){
        print STDERR "Expected #{pretty n} arguments to '#{name}', given " . 
        scalar(@_) . "\n";
        exit 1;
    }
    return `#{poolcall}`;
}
|]
  where
    n = nargs t
    poolcall = hsep $ cmd : map argT [0 .. (n - 1)]

functionCT :: NexusCommand -> MDoc
functionCT (NexusCommand cmd _ json_str args subs) =
  [idoc|
sub call_#{pretty cmd}{
    if(scalar(@_) != #{pretty $ length args}){
        print STDERR "Expected #{pretty $ length args} arguments to '#{pretty cmd}', given " . scalar(@_) . "\n";
        exit 1;
    }
    my $json_obj = $json->decode(q{#{json_str}});
    #{align . vsep $ readArguments ++ replacements}
    return ($json->encode($json_obj) . "\n");
}
|]
  where
    readArguments = zipWith readJsonArg args [1..]
    replacements = map (uncurry3 replaceJson) subs

replaceJson :: JsonPath -> MT.Text -> JsonPath -> MDoc
replaceJson pathTo v pathFrom
  = (access "$json_obj" pathTo)
  <+> "="
  <+> (access ([idoc|$json_#{pretty v}|]) pathFrom)
  <> ";"

access :: MDoc -> JsonPath -> MDoc
access v ps = cat $ punctuate "->" (v : map pathElement ps)  

pathElement :: JsonAccessor -> MDoc
pathElement (JsonIndex i) = brackets (pretty i)
pathElement (JsonKey key) = braces (pretty key)

readJsonArg ::EVar -> Int -> MDoc
readJsonArg v i = [idoc|my $json_#{pretty v} = $json->decode($ARGV[#{pretty i}]); |]

argT :: Int -> MDoc
argT i = "'$_[" <> pretty i <> "]'" 
