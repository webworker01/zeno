
module Zeno.Consensus
  ( module Zeno.Consensus.Types
  , startSeedNode
  , withConsensusNode
  , runConsensus
  , propose
  , step
  , incStep
  , collectMajority
  , collectThreshold
  , collectMembers
  , majorityThreshold
  ) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import Zeno.Process

import Zeno.Consensus.Types
import Zeno.Consensus.Round
import Zeno.Consensus.P2P

import Zeno.Prelude
import Zeno.Console


-- Node -----------------------------------------------------------------------

withConsensusNode :: ConsensusNetworkConfig -> (Zeno ConsensusNode a) -> Zeno () a
withConsensusNode CNC{..} act = do
  withNode netConf do
    p2p <- startP2P seeds
    withContext (`ConsensusNode` p2p) act


startSeedNode :: NetworkConfig -> Bool -> IO ()
startSeedNode nc useui = do
  let cnc = CNC [] nc
  runZeno PlainLog () do
    withUI do
      withConsensusNode cnc $ threadDelay $ 2^62
  where
  withUI = if useui then withConsoleUI LevelDebug else id

