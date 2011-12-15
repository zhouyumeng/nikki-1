
module StoryMode.AutoUpdate where


import Control.Monad.Trans.Error

import Utils

import Base

import StoryMode.Client
import StoryMode.Purchasing


-- | auto updating of the storymode
update :: Application -> (Prose -> IO ()) -> ErrorT [String] IO ()
update app logCommand = catchSomeExceptionsErrorT (singleton . show) $ do
    loginData <- readLoginData
    answer <- ErrorT $ (mapLeft (\ err -> "SERVER-ERROR:" : lines err) <$>
                        askForStoryModeZip loginData)
    case answer of
        (Unauthorized err) ->
            throwError ("UNAUTHORIZED REQUEST:" : lines err)
        (AuthorizedDownload zipUrl version) ->
            installStoryMode app logCommand loginData version zipUrl
