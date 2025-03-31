# Script to prepare Auto-GPT Windows installer
# This script downloads the latest Auto-GPT from GitHub and prepares the installer

# Ensure we stop on error
$ErrorActionPreference = "Stop"

# Banner
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "          Auto-GPT Windows Installer Builder         " -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

# Check if running with admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires admin rights to download and build the installer." -ForegroundColor Red
    Write-Host "Please restart PowerShell as Administrator and try again." -ForegroundColor Red
    exit 1
}

# Create a temporary directory
$tempDir = Join-Path $env:TEMP "AutoGPT_Installer_Build"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -Path $tempDir -ItemType Directory | Out-Null

# Set working directory
Set-Location $tempDir
Write-Host "Working directory: $tempDir" -ForegroundColor Yellow

# Check if Inno Setup is installed
$innoSetupPath = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $innoSetupPath)) {
    Write-Host "Inno Setup is not installed. Downloading and installing..." -ForegroundColor Yellow
    
    # Download Inno Setup
    $innoSetupUrl = "https://jrsoftware.org/download.php/is.exe"
    $innoSetupInstaller = Join-Path $tempDir "innosetup_installer.exe"
    
    try {
        Invoke-WebRequest -Uri $innoSetupUrl -OutFile $innoSetupInstaller
    }
    catch {
        Write-Host "Failed to download Inno Setup. Error: $_" -ForegroundColor Red
        exit 1
    }
    
    # Install Inno Setup silently
    Write-Host "Installing Inno Setup..." -ForegroundColor Yellow
    Start-Process -FilePath $innoSetupInstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait
    
    # Check if installation succeeded
    if (-not (Test-Path $innoSetupPath)) {
        Write-Host "Failed to install Inno Setup." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Inno Setup installed successfully." -ForegroundColor Green
}

# Clone Auto-GPT repository (stable branch)
Write-Host "Cloning Auto-GPT repository..." -ForegroundColor Yellow
git clone -b stable https://github.com/Significant-Gravitas/Auto-GPT.git autogpt_repo

# Copy necessary files from the repository
Write-Host "Copying necessary files..." -ForegroundColor Yellow
Copy-Item -Path "autogpt_repo\.env.template" -Destination "."

# Download or create icon
$iconPath = Join-Path $tempDir "auto_gpt_icon.ico"
try {
    # Create a simple icon (using PowerShell to create a blue square)
    $iconUrl = "https://raw.githubusercontent.com/Significant-Gravitas/Auto-GPT/master/autogpt/app/web/static/favicon.ico"
    Invoke-WebRequest -Uri $iconUrl -OutFile $iconPath
    if (-not (Test-Path $iconPath)) {
        throw "Icon download failed"
    }
}
catch {
    Write-Host "Failed to download icon. Creating a placeholder..." -ForegroundColor Yellow
    
    # As a fallback, we'll use PowerShell to create a simple .ico file
    $drawingAssembly = Add-Type -AssemblyName System.Drawing -PassThru
    $bitmap = New-Object System.Drawing.Bitmap 32, 32
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::Blue)
    $bitmap.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Icon)
    $graphics.Dispose()
    $bitmap.Dispose()
}

# Create installer resources
Write-Host "Creating installer resources..." -ForegroundColor Yellow

# Copy scripts from the repository if they exist, or from our Windows installer scripts
$scriptSource = Join-Path $PSScriptRoot "*.*"
$innoScriptPath = Join-Path $tempDir "auto_gpt_setup.iss"

# Copy all the Windows installer script files to the temp directory
Copy-Item -Path $scriptSource -Destination $tempDir

# Create the installer
Write-Host "Creating installer..." -ForegroundColor Yellow
& $innoSetupPath $innoScriptPath

# Check if the installer was created successfully
$installerPath = Join-Path $tempDir "Auto-GPT_Setup.exe"
if (Test-Path $installerPath) {
    # Copy to the desktop for ease of access
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $finalInstallerPath = Join-Path $desktopPath "Auto-GPT_Setup.exe"
    Copy-Item -Path $installerPath -Destination $finalInstallerPath
    
    Write-Host "=====================================================" -ForegroundColor Green
    Write-Host "Installer created successfully!" -ForegroundColor Green
    Write-Host "Location: $finalInstallerPath" -ForegroundColor Green
    Write-Host "=====================================================" -ForegroundColor Green
}
else {
    Write-Host "Failed to create installer." -ForegroundColor Red
    exit 1
}

# Cleanup
Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
Remove-Item -Path $tempDir -Recurse -Force

Write-Host "Done!" -ForegroundColor Green
