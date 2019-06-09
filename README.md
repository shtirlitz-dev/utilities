# utilities

Diffenrent utilities to be used in Windows

## checkspace

A small utility that check space/tabs usage in Visual Studio C++ projects. Can be used as stand-alone application, but it is more efficient when used as External tool inside Visual Studio

In order to use it do the following:
* select menu item Tools | External Tools...
* press "Add"
* fill the folloing fields
  * Title: Check Spaces
  * Command: <path to checkspaces.exe>
  * Arguments: $(SolutionDir)$(SolutionFileName)
  * check [x] Use Output Window
    
Currently the utility can detect the folloging issues:
  * warning SP0001: ends with space or tab
  * warning SP0002: begins with space
  * warning SP0003: tab inside line  (exept after comments)
  * warning SP0004: space after tab

Versions:
* 09.06.2019: initial commit, warning SP0001-SP0004 implemented

Programming language: Haskell
