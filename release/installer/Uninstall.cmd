@echo off
rem Cry of Fear: Enhanced - uninstaller.
rem Removes Cry of Fear: Enhanced from this Cry of Fear folder and restores the original game files.
rem It runs cof-enhanced\uninstall.ps1 with Windows PowerShell (no administrator rights needed).
rem The installer also keeps a copy in cof-enhanced-backup, for when the cof-enhanced folder is gone.
setlocal
title Cry of Fear: Enhanced - Uninstall
set "UNS=%~dp0cof-enhanced\uninstall.ps1"
if not exist "%UNS%" set "UNS=%~dp0cof-enhanced-backup\uninstall.ps1"
if not exist "%UNS%" goto missing
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%UNS%" -GameDir "%~dp0."
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
:missing
echo Cry of Fear: Enhanced does not seem to be installed here:
echo there is no cof-enhanced or cof-enhanced-backup folder next to Uninstall.cmd.
echo.
pause
exit /b 1
