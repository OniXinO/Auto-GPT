@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo               Auto-GPT Updater                    
echo ===================================================
echo.

:: Check if Git is installed
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo Git is not installed or not in PATH.
    echo Cannot update Auto-GPT without Git.
    echo Please run setup_env.bat which will install Git if needed.
    pause
    exit /b 1
)

:: Check if autogpt directory exists
if not exist "%~dp0\autogpt" (
    echo Auto-GPT directory not found.
    echo Please run setup_env.bat to setup the environment first.
    pause
    exit /b 1
)

:: Check if repository has uncommitted changes
cd "%~dp0\autogpt"
git diff --quiet --exit-code >nul 2>&1
if %errorlevel% neq 0 (
    echo Local changes detected in Auto-GPT directory.
    set /p CONTINUE="Do you want to continue? This will discard local changes. (y/n): "
    if /i not "%CONTINUE%" == "y" (
        echo Update canceled.
        pause
        exit /b 0
    )
    echo Discarding local changes...
    git reset --hard
)

:: Update repository
echo Checking for updates...
git fetch
git rev-parse HEAD >"%TEMP%\old_revision.txt"
git rev-parse origin/stable >"%TEMP%\new_revision.txt"

fc "%TEMP%\old_revision.txt" "%TEMP%\new_revision.txt" >nul 2>&1
if %errorlevel% equ 0 (
    echo Auto-GPT is already up to date.
) else (
    echo Updates found. Updating Auto-GPT...
    git pull origin stable
    
    :: Check if update was successful
    if %errorlevel% neq 0 (
        echo Failed to update Auto-GPT.
        echo Please check your internet connection or try again later.
        pause
        exit /b 1
    )
    
    :: Update dependencies
    echo Updating dependencies...
    call "%~dp0\.venv\Scripts\activate.bat"
    python -m pip install --upgrade pip
    pip install -r requirements.txt
    call "%~dp0\.venv\Scripts\deactivate.bat"
    
    echo Auto-GPT has been updated successfully!
)

:: Check for .env template changes
if exist "%~dp0\autogpt\.env.template" (
    echo Checking for environment template changes...
    fc "%~dp0\autogpt\.env.template" "%~dp0\.env.template" >nul 2>&1
    if %errorlevel% neq 0 (
        echo Environment template has been updated.
        set /p UPDATE_TEMPLATE="Do you want to update your .env.template file? (y/n): "
        if /i "%UPDATE_TEMPLATE%" == "y" (
            copy "%~dp0\autogpt\.env.template" "%~dp0\.env.template" >nul 2>&1
            echo Template file updated.
            
            set /p UPDATE_ENV="Do you want to update your .env file with the new template? (y/n): "
            if /i "%UPDATE_ENV%" == "y" (
                :: Backup current .env file
                if exist "%~dp0\.env" (
                    copy "%~dp0\.env" "%~dp0\.env.backup" >nul 2>&1
                    echo Current .env file backed up to .env.backup
                )
                
                :: Create new .env file from template
                copy "%~dp0\.env.template" "%~dp0\.env" >nul 2>&1
                echo New .env file created from template.
                echo Please update it with your API keys and settings.
                notepad "%~dp0\.env"
            )
        )
    )
)

echo.
echo ===================================================
echo Auto-GPT update process completed!
echo ===================================================

pause
