@echo off
REM ── Pitch Coach Backend Startup Script ──────────────────────────────────────
REM Run this from the backend\ directory after activating your Python venv.
REM
REM First-time setup:
REM   python -m venv venv
REM   venv\Scripts\activate
REM   pip install -r requirements.txt
REM   copy .env.example .env
REM   (edit .env and add your GROQ_API_KEY)
REM
REM Then run:
REM   start.bat

cd /d "%~dp0"

if not exist ".env" (
    echo [ERROR] .env file not found.
    echo Copy .env.example to .env and add your GROQ_API_KEY.
    pause
    exit /b 1
)

echo Starting Pitch Coach API on http://localhost:8000 ...
echo Press Ctrl+C to stop.
REM Using "python -m uvicorn" instead of "uvicorn.exe" to avoid Windows
REM Application Control policy blocking scripts in venv\Scripts\.
venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
