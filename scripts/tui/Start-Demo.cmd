@echo off
cls
setlocal DisableDelayedExpansion
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -File "%~dp0examples\Demo.ps1"
set "qwinsta_exit=%errorlevel%"
if not "%qwinsta_exit%"=="0" pause
exit /b %qwinsta_exit%
