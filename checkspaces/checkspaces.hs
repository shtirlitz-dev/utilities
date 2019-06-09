{-# LANGUAGE OverloadedStrings #-}
{-
    used as Visual Studio tool to check cpp/h/cs files:
    Tools | External Tools... |> Add
    Title: Check Spaces
    Command: <path to checkspaces.exe>
    Arguments: $(SolutionDir)$(SolutionFileName)
    [x] Use Output Window
    
    checks:
    warning SP0001: ends with space or tab
    warning SP0002: begins with space
    warning SP0003: tab inside line  (exept after comments)
    warning SP0004: space after tab
    
    TODO:
    make option:
        - tabs or only spaces
        - suppress warnings
-}

import System.Environment
import qualified Data.Text.Lazy.IO as TIO
import qualified Data.Text.Lazy as T
import Data.List
import Data.Maybe
import System.FilePath.Windows   -- or System.FilePath.Posix  - for Linux/MacOS
import Control.Monad
-- execute "cabal install regex-posix" to get regex
import Text.Regex.Posix

isOption ('-' : x) = True
isOption _ = False

main = do
    args <- getArgs
    let slns = filter (not . isOption) args
    let opts = filter isOption args
    checkCmdLine slns opts

checkCmdLine ([solution_name]) opts = checkSolution solution_name opts
checkCmdLine _ _ = putStrLn "usage: checkspaces <solution> [-options]"

regexProject :: String
regexProject = "Project[^,]*, *\"([^\"]*)"  -- regex in haskell have a lot of limitations

-- extracts "MyProj.vcxproj" from sting "Project(\"{...GUID...}\") = \"MyProj\", \"MyProj.vcxproj\", \"{...GUID...}\""
extractProject :: String -> Maybe String
extractProject str = if length ress > 0 then Just $ (head ress) !! 1 else Nothing
    where ress = str =~ regexProject :: [[String]]


checkSolution :: String -> [String] -> IO ()
checkSolution solution_name options = do
    items <- fmap T.lines $ TIO.readFile solution_name   -- read from file, divide in lines, items id list of Text (module Data.Text.Lazy), i.e.  [T.Text]
    let projs = filter (T.isPrefixOf "Project") items     -- only strings like "Project<bla-bla-bla>"
    let prjfiles = map fromJust $ filter isJust  $ fmap (extractProject . T.unpack) projs -- extract project file names from those strings
    let slndir = takeDirectory solution_name
    let prjpaths = map (combinePath slndir) prjfiles      -- projects files, full paths
    allFiles <- mconcat $ map getProjectFiles prjpaths    -- all source files in all projects of solution
    let srcFiles = nub allFiles                           -- unique files
    putStrLn $ "Checking solution " ++ solution_name ++ "..."
    forM_ (zip [1..] prjpaths) (\(n, s) -> putStrLn $ mconcat [" ", show n, ". Project ", s] )  -- print list of solutions
    putStrLn ""
    -- test source files (file -> statistics)
    statList <- mapM (examSource options) srcFiles
    -- output summary
    let (totLines, totSymbols, totWarns) = foldl (\(ls, ss, es) (l, s, e) -> (ls + l, ss + s, es + e)) (0,0,0) statList
    putStrLn $ mconcat [ "Files: ", show $ length statList, ", Lines: ", show totLines, " Symbols: ", show totSymbols, " Warnings: ", show totWarns ]


getProjectFiles :: String -> IO [String]
getProjectFiles prjfile = do
    -- return [prjfile, prjfile -<.> "ee"]
    items <- fmap T.lines $ TIO.readFile prjfile   -- read from file, divide in lines, items id list of Text (module Data.Text.Lazy), i.e.  [T.Text]
    let srcfiles = filter ("" /=) $ map (getSrcFile . T.unpack) items
    let prjdir = takeDirectory prjfile
    return $ map (combinePath prjdir) srcfiles

combinePath ::  FilePath -> FilePath -> FilePath
combinePath dir ('.' : '.' : fil) = combinePath (takeDirectory dir) (tail fil)
combinePath dir fil = dir </> fil

-- regex is very restricted!
rxSource :: String
rxSource = "<([a-zA-Z]*).*=\"([^\"]*)\""

sourceTypes :: [String]
sourceTypes = ["ClCompile", "ClInclude", "Compile"]

-- seatch these strings and extract file names
-- <ClCompile Include="Texts.cpp" />
-- <ClInclude Include="..\CommonFiles\Unicode.h" />
-- <Compile Include="Program.fs" />
-- <Compile Include="Program.cs" />
-- N.B.: haskell's regex dows not work properly with RE like "<(ClCompile|ClInclude|Compile) ..."
getSrcFile :: String -> String
getSrcFile str = if isFound then itemName else ""
    where
        ress = str =~ rxSource :: [[String]]
        (itemType, itemName) = getTypeName ress
        getTypeName (h : _) = ( h !! 1, h !! 2 )
        getTypeName  _ = ("", "")
        isFound = elem itemType sourceTypes


-- examing source file, prints errors, returns statistics
-- message is like "D:\dir\Options.cpp(18,2): error C2065:  'asd': undeclared identifier

examSource :: [String] -> FilePath -> IO (Int, Int, Int)  -- returns number of lines, number of symbols and number of errors
examSource options srcFiles = do
    srcLines <- fmap T.lines $ TIO.readFile srcFiles   -- read from file, divide in lines, items id list of Text (module Data.Text.Lazy), i.e.  [T.Text]
    let errList = map checkSrcLine srcLines  -- ["","","error msg 1","","","error msg 2",...] - "" is ok
    let lineErr = filter ((> 0) . length . snd) $ zip [1..] errList  -- [(line, error)] where error > 0
    -- write error
    forM_ lineErr (\(n, msg) -> putStrLn $ mconcat [srcFiles, "(", show n, ",", msg] )
    let totLines = length srcLines
    let stsSymbols = sum $ map T.length srcLines
    return (totLines, fromIntegral stsSymbols, length lineErr)

endsWithSpace :: T.Text -> Bool
endsWithSpace txt = let lch = T.last txt in lch == ' ' || lch == '\t'

beginsWithSpace :: T.Text -> Bool
beginsWithSpace txt = T.head txt == ' '


stripTabs :: T.Text -> T.Text
stripTabs txt = T.dropWhile (== '\t') txt

stripTabsAndComments :: T.Text -> T.Text
stripTabsAndComments txt = 
    if T.isPrefixOf "\t" txt then 
        stripTabsAndComments $ stripTabs txt
    else if T.isPrefixOf "//" txt then
        stripTabsAndComments $ T.drop 2 txt
    else
        txt

tabPosFromEnd :: T.Text -> Int
tabPosFromEnd txt = fromIntegral $ T.length $ T.dropWhile (/= '\t') txt
        
insideTabPos :: T.Text -> Int
insideTabPos txt = if tabPosEnd /= 0 then totLen - tabPosEnd else -1
    where
        tabPosEnd = tabPosFromEnd stripped
        stripped = stripTabsAndComments txt
        totLen = fromIntegral $ T.length txt

-- return "" if OK, on error returns "2): error C2065:  'asd': undeclared identifier"
checkSrcLine :: T.Text -> String
checkSrcLine txt = 
    if T.null txt then
        ""
    else if endsWithSpace txt then
        (show $ lineLen + 1) ++ "): warning SP0001: ends with space or tab"
    else if beginsWithSpace txt then
        "1): warning SP0002: begins with space" 
    else if tabPos >= 0 then
        (show $ tabPos + 1) ++ "): warning SP0003: tab inside line"
    else if spaceAfterTab >= 0 then
        (show $ spaceAfterTab + 1) ++ "): warning SP0004: space after tab"
    else ""
    where
        lineLen = T.length txt
        tabPos = insideTabPos txt
        spaceAfterTab = if T.isPrefixOf " " afterTab then  fromIntegral $ lineLen - T.length afterTab else -1
        afterTab = stripTabs txt

