@echo off
rem Cry of Fear: Enhanced - one-click installer.
rem Extract the whole zip into your Cry of Fear folder, then double-click this file.
rem It runs cof-enhanced\install.ps1 with Windows PowerShell (no administrator rights needed).
setlocal
title Cry of Fear: Enhanced - Install
if not exist "%~dp0cof-enhanced\install.ps1" goto missing
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0cof-enhanced\install.ps1" -GameDir "%~dp0."
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
:missing
echo The cof-enhanced folder is missing next to Install.cmd.
echo Extract the WHOLE zip into your Cry of Fear folder, then run Install.cmd again.
echo.
pause
exit /b 1
