@echo off
REM Startet deploy_itch.ps1 unabhaengig von der ExecutionPolicy des Systems.
REM Argumente werden durchgereicht:  deploy_itch.cmd -NoPush -SkipWindows
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_itch.ps1" %*
exit /b %ERRORLEVEL%
