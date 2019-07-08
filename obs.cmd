@echo off
REM Invoke either cygwin or git-for-windows-bash obs, as appropriate
REM Preference is set by project in ci/shell
REM Valid values there are cygwin or gitbash

goto :main

:cygwin
c:\cygwin64\bin\sh -c "PATH=/bin:$PATH; obs %1 %2 %3 %4 %5 %6"
goto :eof

:git-bash
"c:\Program Files\Git\bin\sh.exe" -c "obs %1 %2 %3 %4 %5 %6"
goto :eof

:main
SET /P REALM=<ci\winshell.txt
if x"%REALM%" == x"" goto :fail
if %REALM% == cygwin goto :cygwin
if %REALM% == git-bash goto :git-bash

:fail
exit /b 1

:eof
