{-# LANGUAGE OverloadedStrings #-}

module Network.Ethereum.Data
  ( module ALL
  ) where

import           Data.RLP as ALL hiding (Array, String)

import           Network.Ethereum.Data.ABI as ALL
import           Network.Ethereum.Data.U256 as ALL
import           Zeno.Data.Hex as ALL


-- What's this for again?
--
instance RLPEncodable Hex where
  rlpEncode = rlpEncode . unHex
  rlpDecode = fmap Hex . rlpDecode
