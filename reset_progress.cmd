@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0reset_progress.ps1" %*
if errorlevel 1 (
    echo.
    echo Reset fehlgeschlagen.
    exit /b 1
)
endlocal
