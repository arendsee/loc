{-# LANGUAGE OverloadedStrings #-}

{-|
Module      : Morloc.Component.Util
Description : Utility functions for components
Copyright   : (c) Zebulun Arendsee, 2018
License     : GPL-3
Maintainer  : zbwrnz@gmail.com
Stability   : experimental
-}

module Morloc.Component.Util (
    simpleGraph
  , graphify
  , sendQuery
  , isElement_
) where

import Morloc.Types
import Morloc.Sparql
import qualified Morloc.Data.RDF as MR
import qualified Morloc.Data.Text as MT

import qualified Data.Map.Strict as Map
import qualified Data.Maybe as DM
import qualified Data.List as DL
import qualified Data.List.Extra as DLE

-- | This works for building a map based off a simple tree structure
simpleGraph
  :: (Ord key, Ord a)
  => (    Map.Map key (a, [key])
       -> key
       -> b
     )
  -> ([Maybe MT.Text] -> a) -- prepare the specific data
  -> (MT.Text -> key) -- map a text field to an id
  -> (SparqlEndPoint -> IO [[Maybe MT.Text]])
  -> SparqlEndPoint
  -> IO (Map.Map key b)
simpleGraph f g h query ep
  = fmap (graphify f . map tuplify) (query ep)
  where
    tuplify xs = case (take 3 xs, drop 3 xs) of
      ([Just mid, el, child], rs) -> ((h mid, g rs), (,) <$> el <*> (fmap h child))
      _ -> error "Unexpected SPARQL output"

-- | Build a map of objects from a tree-like structure with parent keys
-- mapping to one or more ordered child ids.
graphify
  :: (Ord index, Ord key, Ord a)
  => (    Map.Map key (a, [key])
       -> key
       -> b
     )
  -> [((key, a), Maybe (index, key))]
  -> Map.Map key b -- one element for each root element
graphify f xs = Map.fromList $ zip roots (map (f hash) roots)
  where
    hash
      = Map.fromList
      . map (\((x,d),ys) -> (x, (d, ys)))
      . map (withSnd (map snd . DL.sort . DM.catMaybes))
      . DLE.groupSort
      $ xs

    roots = [p | ((p,_),_) <- xs, not (elem p [c | (_, Just (_,c)) <- xs])]
  
withSnd :: (a -> b) -> (c, a) -> (c , b)
withSnd f (x, y) = (x, f y)

sendQuery :: Query SelectQuery -> SparqlEndPoint -> IO [[Maybe MT.Text]]
sendQuery query ep = fmap values (selectQuery ep query)
  where
    values :: Maybe [[BindingValue]] -> [[Maybe MT.Text]]
    values Nothing = error "SPARQL command failed"
    values (Just xss) = (fmap . fmap) maybeValue xss

    maybeValue :: BindingValue -> Maybe MT.Text
    maybeValue (Bound (MR.LNode (MR.PlainL  x  ))) = Just x
    maybeValue (Bound (MR.LNode (MR.PlainLL x _))) = Just x
    maybeValue (Bound (MR.LNode (MR.TypedL  x _))) = Just x
    maybeValue (Bound (MR.UNode x))             = Just x
    maybeValue _ = Nothing

isElement_ :: PredicateTermLike a => a -> Query ()
isElement_ x = filterExpr_ (regex (str x) ("_[0-9]+$" :: MT.Text))
