{-# language ScopedTypeVariables #-}

module Base.Renderable.Header (header) where


import Data.Abelian
import Data.Char

import Codec.Binary.UTF8.Light

import Graphics.Qt

import Utils

import Base.Types
import Base.Constants
import Base.Prose
import Base.Font
import Base.Pixmap

import Base.Renderable.HBox
import Base.Renderable.Layered
import Base.Renderable.Centered


-- | implements menu headers
header :: Application_ s -> Prose -> RenderableInstance
header app =
    colorizeProse headerFontColor >>>
    capitalizeProse >>>
    proseToGlyphs app >>>
    fmap (glyphToHeaderCube app) >>>
    addStartAndEndCube app >>>
    hBox >>>
    renderable

data HeaderCube
    = StartCube
    | StandardCube Glyph
    | SpaceCube
    | EndCube
  deriving Show

-- | converts a glyph into a renderable cube for headers
glyphToHeaderCube :: Application_ s -> Glyph -> HeaderCube
glyphToHeaderCube app glyph =
    if isSpaceGlyph glyph then SpaceCube else StandardCube glyph

isSpaceGlyph :: Glyph -> Bool
isSpaceGlyph g = " " == decode (character g)

-- | Adds one cube before and one cube after the header.
addStartAndEndCube :: Application_ s -> [HeaderCube] -> [HeaderCube]
addStartAndEndCube app inner =
    StartCube :
    inner ++
    EndCube :
    []
  where
    pixmaps = headerCubePixmaps $ applicationPixmaps app

instance Renderable HeaderCube where
    render ptr app config size cube = case pixmapCube cube of
        Left getter -> render ptr app config size $ getter pixmaps
        Right glyph -> do
            (childSize, background) <- render ptr app config size $ standardCube pixmaps
            return $ tuple childSize $ do
                recoverMatrix ptr background
                snd =<< render ptr app config (childSize -~ Size (fromUber 1) 0)
                            (centered [glyph])
      where
        pixmaps = headerCubePixmaps $ applicationPixmaps app

-- | Returns (Left getter) if the cube should be rendered by just one pixmap,
-- (Right glyph) otherwise.
pixmapCube :: HeaderCube -> Either (HeaderCubePixmaps -> Pixmap) Glyph
pixmapCube cube = case cube of
    StartCube -> Left startCube
    SpaceCube -> Left spaceCube
    EndCube -> Left endCube
    StandardCube x -> Right x
