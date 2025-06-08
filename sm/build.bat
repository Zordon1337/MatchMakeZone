@echo off
set COMPILER=D:\sourcemod\addons\sourcemod\scripting\spcomp.exe
set INCLUDE=D:\sourcemod\addons\sourcemod\scripting\include

%COMPILER% plugin.sp -i"%INCLUDE%" -o"plugin.smx"
pause
