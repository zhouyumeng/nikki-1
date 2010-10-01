#!/usr/bin/env runhaskell --version


import Data.Initial

import Control.Monad

import System.Directory
import System.FilePath

import Editor.Pickle


main = do
    exists <- doesDirectoryExist dir
    when (not exists) $
        error (dir ++ " does not exist")
    let path = dir </> "empty.nl"
    putStrLn ("writing empty level to " ++ show path)
    writeSaved path initial


dir = "../../data/template_levels"
