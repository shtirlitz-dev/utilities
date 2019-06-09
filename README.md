# utilities

Small utilities (so far only one) to be used in Windows

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
  * line ends with space or tab
  * line begins with space
  * line tab inside line  (exept after comments)
  * line space after tab

Versions:
* 09.06.2019: initial commit, warnings SP0001-SP0004 implemented

**checkspace** writes statistics: number of files checked, number of lines in these files, total number of symbols in these lines (cr/lf not included), number of found errors

Sample output:
```
Checking solution D:\Projects\shtirlitz-dev\git.shtirlitz\ShtitlitzApp\Shtirlitz.sln...
 1. Project D:\Projects\shtirlitz-dev\ShtitlitzApp\Shtirlitz.vcxproj

D:\Projects\shtirlitz-dev\CommonFiles\BaseCls.cpp(33,1): warning SP0002: begins with space
D:\Projects\shtirlitz-dev\CommonFiles\BaseCls.cpp(127,26): warning SP0001: ends with space or tab
D:\Projects\shtirlitz-dev\CommonFiles\Unicode.cpp(543,2): warning SP0004: space after tab
...
D:\Projects\shtirlitz-dev\ShtitlitzApp\OptionsDlg.h(122,5): warning SP0003: tab inside line
Files: 43, Lines: 34397 Symbols: 866390 Warnings: 1486
```

Programming language: Haskell
