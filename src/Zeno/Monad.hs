{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes #-}

module Zeno.Monad where

import Control.Exception.Safe (MonadMask)
import Control.Monad.Catch (MonadCatch)
import Control.Monad.Logger
import Control.Monad.Reader
import Control.Monad.Trans.Resource as ResourceT
import UnliftIO

import Zeno.Logging
import Zeno.Console.Types

--------------------------------------------------------------------------------
-- | Zeno App context
--------------------------------------------------------------------------------

data ZenoApp r = App
  { appContext   :: r
  , appConsole   :: Console
  , appResources :: ResourceT.InternalState
  }

instance Functor ZenoApp where
  fmap f z = z { appContext = f (appContext z) }

--------------------------------------------------------------------------------
-- | Zeno monad and instances
--------------------------------------------------------------------------------

newtype Zeno r a =
  Zeno { unZeno :: forall ret. (ZenoApp r -> a -> IO ret) -> ZenoApp r -> IO ret }

instance Functor (Zeno r) where
  fmap f (Zeno p) = Zeno $
    \rest -> p (\app -> rest app . f)
  {-# INLINE fmap #-}

instance Applicative (Zeno r) where
  pure = return
  {-# INLINE pure #-}
  (<*>) = ap
  {-# INLINE (<*>) #-}

instance Monad (Zeno r) where
  return x = Zeno $ \f app -> f app x
  {-# INLINE return #-}
  Zeno f >>= g = Zeno $
    \rest -> f (\app a -> unZeno (g a) rest app)
  {-# INLINE (>>=) #-}

instance Semigroup a => Semigroup (Zeno r a) where
  ma <> mb = (<>) <$> ma <*> mb

instance Monoid a => Monoid (Zeno r a) where
  mempty = pure mempty

instance MonadIO (Zeno r) where
  liftIO io = Zeno $ \f app -> io >>= f app

instance MonadUnliftIO (Zeno r) where
  withRunInIO inner = Zeno
    \f app -> inner (\(Zeno z) -> z (\_ -> pure) app) >>= f app

instance MonadReader r (Zeno r) where
  ask = Zeno $ \f app -> f app $ appContext app
  {-# INLINE ask #-}
  local = withContext

instance MonadResource (Zeno r) where
  liftResourceT resT = Zeno
    \f app -> runInternalState resT (appResources app) >>= f app

instance MonadLogger (Zeno r) where
  monadLoggerLog a b c d = Zeno
    \rest app -> logMessage (appConsole app) a b c d >>= rest app

instance MonadLoggerIO (Zeno r) where
  askLoggerIO = Zeno
    \rest app -> rest app (logMessage (appConsole app))

instance MonadFail (Zeno r) where
  fail = error

--------------------------------------------------------------------------------
-- | Zeno runners
--------------------------------------------------------------------------------

runZeno :: Console -> r -> Zeno r a -> IO a
runZeno console r act = unZeno (withLocalResources act) (\_ -> pure) app 
  where app = App r console undefined

localZeno :: (ZenoApp r -> ZenoApp r') -> Zeno r' a -> Zeno r a
localZeno f (Zeno z) = Zeno \rest app -> z (\_ -> rest app) (f app)
{-# INLINE localZeno #-}

withLocalResources :: Zeno r a -> Zeno r a
withLocalResources z = do
  bracket ResourceT.createInternalState
          ResourceT.closeInternalState
          (\rti -> localZeno (\app -> app { appResources = rti }) z)

withContext :: (r -> r') -> Zeno r' a -> Zeno r a
withContext = localZeno . fmap

getConsole :: Zeno r Console
getConsole = Zeno \rest app -> rest app (appConsole app)

--------------------------------------------------------------------------------
-- | Has typeclass
--------------------------------------------------------------------------------

class Has r a where
  has :: a -> r

instance Has r r where
  has = id

hasReader :: Has r' r => Zeno r' a -> Zeno r a
hasReader = withContext has

