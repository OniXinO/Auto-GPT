@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo               Auto-GPT Launcher                  
echo ===================================================
echo.

:: Check if Python is installed
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo Python is not installed or not in PATH.
    echo Please run setup_env.bat to install Python and dependencies.
    pause
    exit /b 1
)

:: Check if .env file exists, if not, copy from template
if not exist "%~dp0\.env" (
    echo Environment file not found, creating from template...
    copy "%~dp0\.env.template" "%~dp0\.env" >nul 2>&1
    echo Please edit the .env file to add your OpenAI API key.
    notepad "%~dp0\.env"
)

:: Create workspace directory if it doesn't exist
if not exist "%~dp0\auto_gpt_workspace" (
    mkdir "%~dp0\auto_gpt_workspace"
    echo Created workspace directory.
)

:: Check if .venv exists
if not exist "%~dp0\.venv" (
    echo Virtual environment not found.
    echo Please run setup_env.bat to install dependencies.
    pause
    exit /b 1
)

:: Activate virtual environment and run Auto-GPT
echo Starting Auto-GPT...
call "%~dp0\.venv\Scripts\activate.bat"
python "%~dp0\autogpt\__main__.py" %*

:: Deactivate virtual environment when done
call "%~dp0\.venv\Scripts\deactivate.bat"
pause
