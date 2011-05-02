{-# language ViewPatterns, DeriveDataTypeable #-}

-- | provides a data type for pixmaps that saves the size and the internal offset (padding)
-- of the image.
-- Padding is the outer part of the image that should not be considered as part of 
-- the physical object depictured by the image, e.g. an outer glow.

module Base.Pixmap where


import Data.Abelian
import Data.Data
import Data.Accessor

import Control.Monad.IO.Class

import Graphics.Qt
import Physics.Chipmunk (Angle, rad2deg)

import Utils


type Offset a = Position a

data Pixmap = Pixmap {
    pixmap :: Ptr QPixmap,
    pixmapOffset_ :: Position Double,
    pixmapSize :: Size Double,
    pixmapImageSize :: Size Double
  }
    deriving (Show, Eq, Typeable, Data)

pixmapOffset :: Accessor Pixmap (Position Double)
pixmapOffset = accessor pixmapOffset_ (\ a r -> r{pixmapOffset_ = a})


-- | Loads a pixmap with a symmetric offset (right == left && above == below).
loadSymmetricPixmap :: MonadIO m =>
    Position Int -- ^ Offset of the object in the image
    -> FilePath -> m Pixmap
loadSymmetricPixmap padding path = io $ do
    pix <- newQPixmap path
    size <- sizeQPixmap pix
    return $ Pixmap
        pix
        (fmap (fromIntegral . negate) padding)
        (fmap fromIntegral (size -~ fmap (* 2) (positionToSize padding)))
        (fmap fromIntegral size)

-- | Loads a pixmap.
-- The offset and size define the offset and size of the object in the picture.
loadPixmap :: MonadIO m => FilePath -> Offset Double -> Size Double -> m Pixmap
loadPixmap file offset size = io $ do
    pixmap <- newQPixmap file
    imageSize <- fmap fromIntegral <$> sizeQPixmap pixmap
    return $ Pixmap pixmap (fmap negate offset) size imageSize

-- | release the resource
freePixmap :: MonadIO m => Pixmap -> m ()
freePixmap = pixmap >>> io . destroyQPixmap

-- | copy a pixmap
copyPixmap :: Pixmap -> IO Pixmap
copyPixmap (Pixmap pix size offset imageSize) = do
    pixCopy <- copyQPixmap pix
    return $ Pixmap pixCopy size offset imageSize

-- | Change the pixel colors of a given pixmap using the given function.
-- Not very efficient, since the Pixmap is converted to a QImage in between.
mapPixels :: (QRgb -> QRgb) -> Pixmap -> IO Pixmap
mapPixels f (Pixmap pix size offset realSize) = do
    image <- toImageQPixmap pix
    destroyQPixmap pix
    imageSize <- sizeQImage image
    let xs = [0 .. (width imageSize - 1)]
        ys = [0 .. (height imageSize - 1)]
    forM_ (cartesian ys xs)  $ \ (y, x) -> do
        c <- pixelQImage image (x, y)
        setPixelQImage image (x, y) (f c)
    newPix <- fromImageQPixmap image
    destroyQImage image
    return $ Pixmap newPix size offset realSize


-- * rendering

-- | renders the pixmap
renderPixmap :: MonadIO m =>
    Ptr QPainter -- ^ painter to be rendered to
    -> Offset Double -- ^ global (camera) offset
    -> Position Double -- ^ position of pixmap
    -> Maybe Angle -- ^ rotation
    -> Pixmap -- ^ pixmap to be rendered
    -> m ()
renderPixmap ptr offset position mAngle pix = io $ do
    resetMatrix ptr
    translate ptr offset

    translate ptr position
    whenMaybe mAngle $ \ angle ->
        rotate ptr (rad2deg angle)
    translate ptr (pix ^. pixmapOffset)

    drawPixmap ptr zero (pixmap pix)

-- | renders a Pixmap without altering the painter matrix
renderPixmapSimple :: MonadIO m => Ptr QPainter -> Pixmap -> m ()
renderPixmapSimple ptr pix = io $
    drawPixmap ptr (fmap round (pix ^. pixmapOffset)) (pixmap pix)

-- | pixmap with rendering information (position and angle)
data RenderPixmap
    = RenderPixmap {
        getRenderPixmap :: Pixmap,
        renderPosition_ :: Position Double,
        renderAngle :: Maybe Angle
      }
  deriving (Show, Typeable, Data)

renderPosition :: Accessor RenderPixmap (Position Double)
renderPosition = accessor renderPosition_ (\ a r -> r{renderPosition_ = a})

-- | renders a pixmap
doRenderPixmap :: Ptr QPainter -> RenderPixmap -> IO ()
doRenderPixmap ptr (RenderPixmap pix position mAngle) = do
    resetMatrix ptr
    translate ptr position
    whenMaybe mAngle $ \ angle ->
        rotate ptr (rad2deg angle)
    translate ptr (pix ^. pixmapOffset)

    drawPixmap ptr zero (pixmap pix)
