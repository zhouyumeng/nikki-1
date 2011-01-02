{-# language ScopedTypeVariables #-}

-- | The (real) main (that is, entry-) module for the game

module Game.MainLoop (
    gameLoop,
    GameState(..)
  ) where


import Data.Initial

import Control.Monad.State hiding ((>=>))
import Control.Concurrent
import Clocked

import Physics.Chipmunk as CM

import Graphics.Qt

import Utils

import Base

import Object

import Game.Scene


-- prints the version number of qt and exits
debugQtVersion :: IO ()
debugQtVersion = do
    v <- qtVersion
    putStrLn ("Qt-Version: " ++ v)


-- * running the state monad inside the render IO command
-- renderCallback :: Application -> IORef GameAppState -> [QtEvent] -> Ptr QPainter -> IO ()
-- renderCallback app stateRef qtEvents painter = do
--     let allEvents = toEitherList qtEvents []
-- 
--     state <- readIORef stateRef
--     ((), state') <- runStateT (renderWithState app painter) state
--     writeIORef stateRef state'

-- Application Monad and State

type AppMonad o = StateT GameState IO o

data GameState = GameState {
    cmSpace :: CM.Space,
    scene :: Scene Object_
  }

setScene :: GameState -> Scene Object_ -> GameState
setScene s x = s{scene = x}


-- | main loop for logic thread in gaming mode
-- the sceneMVar has to be empty initially.
gameLoop :: Application -> MVar (Scene Object_, DebuggingCommand) -> AppMonad AppState
gameLoop app sceneMVar = do
    initializeSceneMVar
    timer <- io $ newTimer
    withArrowAutoRepeat app $
        loop timer
  where
    loop :: Timer -> StateT GameState IO AppState
    loop timer = do
        io $ resetDebugging

        -- input events
        controlData <- io $ pollAppEvents $ keyPoller app

        -- stepping of the scene (includes rendering)
        space <- gets cmSpace
        sc <- gets scene
        sc' <- io $ stepScene space controlData sc
        puts setScene sc'

        swapSceneMVar =<< io getDebugging

        let startPressed = Press StartButton `elem` pressed controlData
        case mode sc' of
            LevelFinished t _ ->
                if startPressed then
                    return FinalState
                else if spaceTime sc' - t > levelEndDuration then
                    return FinalState
                else continue
            _ -> if startPressed then do
                io $ putStrLn "NYI: game menu"
                return FinalState -- TODO: should be a menu
              else continue
      where
        continue = do
            io $ waitTimer timer (stepQuantum / timeFactor)
            loop timer

    initializeSceneMVar :: AppMonad ()
    initializeSceneMVar = do
        empty <- io $ isEmptyMVar sceneMVar
        when (not empty) $ fail "sceneMVar has to be empty"
        s <- gets scene
        immutableCopyOfScene <- io $ Game.Scene.immutableCopy s
        io $ putMVar sceneMVar (immutableCopyOfScene, initial)
    swapSceneMVar :: DebuggingCommand -> AppMonad ()
    swapSceneMVar debugging= do
        s <- gets scene
        io $ do
            immutableCopyOfScene <- Game.Scene.immutableCopy s
            swapMVar sceneMVar (immutableCopyOfScene, debugging)
            return ()

withArrowAutoRepeat :: MonadIO m => Application -> m a -> m a
withArrowAutoRepeat app cmd = do
    io $ setArrowAutoRepeat (window app) False
    a <- cmd
    io $ setArrowAutoRepeat (window app) True
    return a
