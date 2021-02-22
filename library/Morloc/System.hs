{-|
Module      : Morloc.System
Description : Handle dependencies and environment setup
Copyright   : (c) Zebulun Arendsee, 2020
License     : GPL-3
Maintainer  : zbwrnz@gmail.com
Stability   : experimental
-}
module Morloc.System
  ( loadYamlConfig
  , getHomeDirectory
  , getCurrentDirectory
  , canonicalizePath
  , appendPath
  , takeDirectory
  , takeFileName
  , takeExtensions
  , dropExtensions 
  , combine
  , joinPath
  , fileExists
  ) where

import Morloc.Namespace 
import qualified Morloc.Data.Text as MT

import Data.Aeson (FromJSON(..))
import qualified Data.Yaml.Config as YC
import qualified System.Directory as Sys
import qualified System.FilePath.Posix as Path
import qualified System.Directory as SD

combine :: Path -> Path -> Path
combine (Path x) (Path y) = Path . MT.pack $ Path.combine (MT.unpack x) (MT.unpack y)

joinPath :: [Path] -> Path
joinPath = Path . MT.pack . Path.joinPath . map (MT.unpack . unPath)

fileExists :: Path -> IO Bool
fileExists = SD.doesFileExist . MT.unpack . unPath

takeDirectory :: Path -> Path
takeDirectory (Path x) = Path . MT.pack . Path.takeDirectory $ MT.unpack x

takeFileName :: Path -> Path
takeFileName (Path x) = Path . MT.pack . Path.takeFileName $ MT.unpack x

takeExtensions :: Path -> MT.Text
takeExtensions (Path x) = MT.pack . Path.takeExtensions $ MT.unpack x

dropExtensions :: Path -> MT.Text
dropExtensions (Path x) = MT.pack . Path.dropExtensions $ MT.unpack x

-- | Append POSIX paths encoded as Text
appendPath :: Path -> Path -> Path
appendPath base path = combine path base

getHomeDirectory :: IO Path
getHomeDirectory = fmap (Path . MT.pack) Sys.getHomeDirectory

getCurrentDirectory :: IO Path
getCurrentDirectory = fmap (Path . MT.pack) SD.getCurrentDirectory

canonicalizePath :: Path -> IO Path
canonicalizePath (Path x) = fmap (Path . MT.pack) (SD.canonicalizePath (MT.unpack x))

loadYamlConfig ::
     FromJSON a
  => Maybe [Path] -- ^ possible locations of the config file 
  -> YC.EnvUsage -- ^ default values taken from the environment (or a hashmap)
  -> IO a -- ^ default configuration
  -> IO a
loadYamlConfig (Just fs) e _ = YC.loadYamlSettings (map (MT.unpack . unPath) fs) [] e
loadYamlConfig Nothing _ d = d
