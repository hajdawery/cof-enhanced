@echo off
setlocal
pushd "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0extract-actual.ps1" %*
if errorlevel 1 goto :fail
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if errorlevel 1 goto :fail
cl.exe /nologo /W4 /TC menu_save_fault_harness.c /Fe:menu_save_fault_harness.exe
if errorlevel 1 goto :fail
menu_save_fault_harness.exe
set "rc=%errorlevel%"
goto :done
:fail
set "rc=%errorlevel%"
:done
popd
endlocal & exit /b %rc%
