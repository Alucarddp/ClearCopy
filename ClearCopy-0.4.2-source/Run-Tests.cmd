@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-Tests.ps1"
echo.
echo Exit code %ERRORLEVEL%. Full log: "%~dp0test-log.txt"
pause
