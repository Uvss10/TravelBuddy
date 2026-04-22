@echo off
title TravelBuddy AI — Auto-Restart Server
color 0A
cd /d "%~dp0"

:LOOP
echo.
echo  [%TIME%] Starting TravelBuddy server on http://127.0.0.1:8000
echo  ------------------------------------------------------------

:: Kill anything on port 8000
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":8000 " ^| findstr "LISTENING"') do (
    taskkill /PID %%a /F >nul 2>&1
)

:: Start server
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000

:: If it crashes, wait 3 seconds and restart automatically
echo.
echo  [%TIME%] Server stopped. Restarting in 3 seconds... (Ctrl+C to quit)
timeout /t 3 /nobreak >nul
goto LOOP
