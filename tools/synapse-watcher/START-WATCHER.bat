@echo off
REM SYNAPSE Watcher Launcher for Windows
REM Double-click this to start the watcher

echo ========================================
echo   SYNAPSE Watcher - Starting...
echo ========================================
echo.

REM Check if Claude Code is installed
where claude >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Claude Code CLI not found!
    echo.
    echo Install Claude Code first:
    echo https://docs.anthropic.com/claude-code
    echo.
    pause
    exit /b 1
)

REM Run the PowerShell watcher
powershell -ExecutionPolicy Bypass -File "%~dp0watcher-windows.ps1"

pause
