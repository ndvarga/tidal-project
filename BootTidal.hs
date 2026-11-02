:set -package containers
:set -fno-warn-orphans -Wno-type-defaults -XMultiParamTypeClasses -XOverloadedStrings
:set prompt ""

-- Import all the boot functions and aliases.
import Sound.Tidal.Boot

default (Rational, Integer, Double, Pattern String)

-- Create a Tidal Stream with the default settings.
-- To customize these settings, use 'mkTidalWith' instead
tidalInst <- mkTidal

-- tidalInst <- mkTidalWith [(superdirtTarget { oLatency = 0.01 }, [superdirtShape])] (defaultConfig { cFrameTimespan = 1/50, cProcessAhead = 1/20})

-- This orphan instance makes the boot aliases work!
-- It has to go after you define 'tidalInst'.
instance Tidally where tidal = tidalInst

-- `enableLink` and `disableLink` can be used to toggle synchronisation using the Link protocol.
-- Uncomment the next line to enable Link on startup.
-- enableLink

-- You can also add your own aliases in this file. For example:
-- fastsquizzed pat = fast 2 $ pat # squiz 1.5

-- :runblocks [file]  evaluates a .tidal file block by block (blocks are
-- separated by blank lines), as if you pressed Ctrl+Enter on each one in order.
-- Without a file it runs main.tidal. Comment-only blocks, a block that is just
-- hush, and blocks that start with a GHCi command (like the :runblocks line
-- itself) are skipped.
import qualified Data.Char
:{
runBlocksScript :: String -> String
runBlocksScript src = unlines (concatMap wrap (filter runnable (blocks (lines (filter (/= '\r') src)))))
  where
    blank = null . dropWhile Data.Char.isSpace
    blocks ls = case dropWhile blank ls of
      [] -> []
      xs -> let (b, rest) = break blank xs in b : blocks rest
    isComment l = take 2 (dropWhile Data.Char.isSpace l) == "--"
    trim = reverse . dropWhile Data.Char.isSpace . reverse . dropWhile Data.Char.isSpace
    runnable b = case filter (not . isComment) b of
      [] -> False
      [l] | trim l == "hush" -> False
      (l : _) -> take 1 (dropWhile Data.Char.isSpace l) /= ":"
    wrap b = [":{"] ++ b ++ [":}"]
:}
:def runblocks (\f -> runBlocksScript <$> readFile (if null f then "D:/Documents/School/Fall26/INAM7000/unparty/tidal-project/main.tidal" else f))

-- :songs  re-evaluates the "songs <- setSongs" block of main.tidal (read from
-- the saved file), so a song you just re-evaluated with Ctrl+Enter is heard.
:{
songsBlockScript :: String -> String
songsBlockScript src = case filter hasSongs (blocks (lines (filter (/= '\r') src))) of
    [] -> "putStrLn \"Mix-Matrix: no 'songs <- setSongs' block found in main.tidal\""
    bs -> unlines (concat [[":{"] ++ b ++ [":}"] | b <- bs])
  where
    blank = null . dropWhile Data.Char.isSpace
    blocks ls = case dropWhile blank ls of
      [] -> []
      xs -> let (b, rest) = break blank xs in b : blocks rest
    hasSongs = any ((== "songs <- setSongs") . take 17)
:}
:def songs (\_ -> songsBlockScript <$> readFile "D:/Documents/School/Fall26/INAM7000/unparty/tidal-project/main.tidal")

:set prompt "tidal> "
:set prompt-cont ""
