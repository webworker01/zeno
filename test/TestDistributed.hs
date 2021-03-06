
module TestDistributed where

-- import TestUtils
-- 
-- import Control.Monad.Reader
-- import qualified Data.ByteString as BS
-- 
-- import qualified StmContainers.Map as STM
-- 
-- import Network.Distributed
-- import Network.Distributed.Remote
-- import qualified Network.Transport as NT
-- import Network.Transport.InMemory
-- import qualified Network.Transport.TCP as TCP
-- import UnliftIO
-- 
-- runTestProc :: ReaderT (ProcessData ()) IO () -> ProcessData () -> IO ()
-- runTestProc = runReaderT
-- 
-- test_process = testGroup "process management"
--   [
--     testCase "startNode" do
--       Node{..} <- createTransport >>= startNode
--       BS.length salt @?= 32
--       salt == BS.replicate 0 32 @?= False
--       pure ()
-- 
--   , testCase "spawn: Cleanup" do
--       node <- createTransport >>= startNode
--       handoff <- newEmptyMVar
--       handle <- nodeSpawn' node $ runTestProc $ getMyPid >>= putMVar handoff
--       takeMVar handoff >>= (@?= procId handle)
--       Right () <- waitCatch (procAsync handle)
--       Nothing <- atomically $ getVoidProcessById node $ procId handle
-- 
--       assertNProcs node 1
-- 
--   , testCase "spawnChild: terminate parent terminates child" do
--       node <- createTransport >>= startNode
--       syncChild <- newEmptyMVar
--       handoffChild <- newEmptyMVar
--       parent <- nodeSpawn' node $ runTestProc do
--         child <- spawnChild do
--           putMVar syncChild ()
--           putMVar syncChild ()               -- will block
--         putMVar handoffChild child
--         putMVar handoffChild child           -- will block
-- 
--       readMVar syncChild
--       child <- readMVar handoffChild
--       assertNProcs node 3
-- 
--       killProcess node $ procId parent
--       waitCatch (procAsync parent) >>= (\e -> show e @?= "Left AsyncCancelled")
--       waitCatch (procAsync child) >>= (\e -> show e @?= "Left AsyncCancelled")
--       assertNProcs node 1
-- 
--   , testCase "spawnChild: parent returns normally terminates child" do
--       node <- createTransport >>= startNode
--       syncChild <- newMVar ()
--       handoffChild <- newEmptyMVar
--       parent <- nodeSpawn' node $ runTestProc do
--         child <- spawnChild do
--           putMVar syncChild ()
--           putMVar syncChild ()               -- will block
--         putMVar handoffChild child
-- 
--       takeMVar syncChild
--       assertNProcs node 2
--       readMVar syncChild
--       child <- readMVar handoffChild
--       Right () <- waitCatch (procAsync parent)
-- 
--       killProcess node $ procId parent
--       waitCatch (procAsync child) >>= (\e -> show e @?= "Left AsyncCancelled")
--       assertNProcs node 1
-- 
--   , testCase "test local process send and receive" do
--       node@Node{endpoint} <- createTransport >>= startNode
-- 
--       sync <- newEmptyMVar :: IO (MVar String)
-- 
--       p1 <- nodeSpawn node $ runReaderT do
--         receiveWait >>= putMVar sync
-- 
--       p2 <- nodeSpawn node $ runTestProc do
--         send (procId p1) ("Hello" :: String)
-- 
--       waitCatch (procAsync p1) >>= (\e -> show e @?= "Right ()")
--       waitCatch (procAsync p2) >>= (\e -> show e @?= "Right ()")
--       
--       readMVar sync >>= (@?= "Hello")
--   ]
-- 
-- 
-- test_messaging = testGroup "local messaging"
--   [
--     testCase "local send / receive" do
--       sync <- newEmptyMVar
--       node <- createTransport >>= startNode
--       p1 <- nodeSpawn node $ runReaderT do
--         receiveWait >>= putMVar sync
--       p2 <- nodeSpawn node $ runTestProc do
--         send (procId p1) ()
--       () <- readMVar sync
--       pure ()
-- 
--   , testCase "receiveTimeout Nothing" do
--       node <- createTransport >>= startNode
-- 
--       sync <- newEmptyMVar
--     
--       p1 <-
--         nodeSpawn node $ runReaderT do
--           receiveTimeoutS 0 >>=
--             \case Nothing -> putMVar sync ()
--                   Just () -> fail "Should not be here"
-- 
--       takeMVar sync
-- 
--   , testCase "receiveTimeout Just" do
--       node <- createTransport >>= startNode
-- 
--       sync <- newEmptyMVar
-- 
--       p1 <-
--         nodeSpawn node $ runReaderT do
--           Just () <- receiveTimeoutS 1
--           putMVar sync ()
-- 
--       p2 <-
--         nodeSpawn node $ runTestProc do
--           send (procId p1) ()
-- 
--       takeMVar sync
-- 
--   ]
-- 
-- 
-- test_remote = testGroup "remote send/receive"
--   [
--     testCase "can send and receive" do
--       node@Node{endpoint} <- createTransport >>= startNode
--       let myNodeId = NodeId $ NT.address endpoint
-- 
--       sync <- newEmptyMVar :: IO (MVar String)
-- 
--       p1 <- nodeSpawn node $ runReaderT do
--         receiveWaitRemote >>=
--           \(RemoteMessage theirNodeId msg) -> do
--             putMVar sync msg
-- 
--       p2 <- nodeSpawn node $ runTestProc do
--         sendRemote myNodeId (procId p1) ("Hello" :: String)
-- 
--       waitCatch (procAsync p1) >>= (\e -> show e @?= "Right ()")
--       waitCatch (procAsync p2) >>= (\e -> show e @?= "Right ()")
--       
--       readMVar sync >>= (@?= "Hello")
-- 
--   , testCase "remote monitor" do
--       -- let host = "127.0.0.1"
--       -- let create port = TCP.createTransport (TCP.defaultTCPAddr host $ show port) TCP.defaultTCPParameters
--       -- Right t1 <- create 7928
--       -- Right t2 <- create 7929
-- 
--       t1 <- createTransport
--       let t2 = t1
-- 
--       node1 <- startNode t1
--       node2 <- startNode t2
--       let end1 = NodeId $ NT.address $ endpoint node1
--       let end2 = NodeId $ NT.address $ endpoint node2
-- 
--       fin <- newEmptyMVar
--       sync <- newEmptyMVar
-- 
--       p1 <- nodeSpawn node1 $ runReaderT do
--         RemoteMessage _ True  <- receiveWaitRemote
--         putMVar sync ()
--         readMVar fin
--         fail "should not be here because node1 got closed"
-- 
--       p2 <- nodeSpawn node2 $ runTestProc do
--         sendRemote end1 (procId p1) True
--         monitorRemote end1 do
--           putMVar fin ()
--         putMVar sync ()
-- 
--       takeMVar sync >> takeMVar sync
--       closeNode node1
-- 
--       takeMVar fin
--   ]
-- 
-- 
-- 
-- assertNProcs node n = 
--   atomically (STM.size $ processes node) >>= (@?= n)
