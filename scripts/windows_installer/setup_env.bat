@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo             Auto-GPT Setup Environment            
echo ===================================================
echo.

:: Set Python version requirements
set MIN_PYTHON_VERSION=3.10

:: Check if Python is installed
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo Python is not installed or not in PATH.
    echo Please install Python %MIN_PYTHON_VERSION% or higher from https://www.python.org/downloads/
    echo Make sure to check "Add Python to PATH" during installation.
    pause
    exit /b 1
)

:: Check Python version
for /f "tokens=2" %%i in ('python -c "import sys; print(sys.version.split()[0])"') do set PYTHON_VERSION=%%i
for /f "tokens=1,2 delims=." %%a in ("%PYTHON_VERSION%") do (
    set PYTHON_MAJOR=%%a
    set PYTHON_MINOR=%%b
)

if %PYTHON_MAJOR% LSS 3 (
    echo Python version %PYTHON_VERSION% is not supported.
    echo Please install Python %MIN_PYTHON_VERSION% or higher.
    pause
    exit /b 1
)

if %PYTHON_MAJOR% EQU 3 (
    if %PYTHON_MINOR% LSS 10 (
        echo Python version %PYTHON_VERSION% is not supported.
        echo Please install Python %MIN_PYTHON_VERSION% or higher.
        pause
        exit /b 1
    )
)

echo Using Python %PYTHON_VERSION%

:: Create virtual environment if it doesn't exist
if not exist "%~dp0\.venv" (
    echo Creating virtual environment...
    python -m venv "%~dp0\.venv"
    if %errorlevel% neq 0 (
        echo Failed to create virtual environment.
        pause
        exit /b 1
    )
)

:: Clone repository if autogpt directory doesn't exist or update if it does
if not exist "%~dp0\autogpt" (
    echo Downloading Auto-GPT...
    :: Check if git is installed
    where git >nul 2>&1
    if %errorlevel% neq 0 (
        echo Git is not installed. Downloading Git installer...
        powershell -Command "Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe' -OutFile '%TEMP%\git-installer.exe'"
        echo Installing Git...
        "%TEMP%\git-installer.exe" /VERYSILENT /NORESTART
        :: Add Git to PATH for current session
        set "PATH=%PATH%;C:\Program Files\Git\cmd"
    )
    
    :: Clone the stable branch
    git clone -b stable https://github.com/Significant-Gravitas/Auto-GPT.git "%~dp0\autogpt"
) else (
    echo Auto-GPT directory found, checking for updates...
    cd "%~dp0\autogpt"
    git pull
)

:: Activate virtual environment and install dependencies
echo Installing dependencies...
call "%~dp0\.venv\Scripts\activate.bat"

:: Upgrade pip
python -m pip install --upgrade pip

:: Install requirements
cd "%~dp0\autogpt"
pip install -r requirements.txt

:: Copy .env template if it doesn't exist
if not exist "%~dp0\.env" (
    copy "%~dp0\autogpt\.env.template" "%~dp0\.env" >nul 2>&1
    echo Copied .env template. You need to edit it with your OpenAI API key.
)

:: Ask user if they want to configure the OpenAI API key
set /p CONFIGURE_API="Do you want to configure your OpenAI API key now? (y/n): "
if /i "%CONFIGURE_API%" == "y" (
    set /p API_KEY="Enter your OpenAI API key: "
    powershell -Command "(Get-Content '%~dp0\.env') -replace 'OPENAI_API_KEY=.*', 'OPENAI_API_KEY=%API_KEY%' | Set-Content '%~dp0\.env'"
    echo OpenAI API key configured!
) else (
    echo Please edit the .env file manually to add your OpenAI API key.
    echo The file is located at: %~dp0\.env
)

echo.
echo ===================================================
echo Auto-GPT environment setup complete!
echo.
echo To run Auto-GPT, use the run_auto_gpt.bat script.
echo ===================================================

:: Deactivate virtual environment
call "%~dp0\.venv\Scripts\deactivate.bat"
pause
