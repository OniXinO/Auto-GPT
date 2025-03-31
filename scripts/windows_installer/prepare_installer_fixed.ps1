# Script to prepare Auto-GPT Windows installer
# This script downloads the latest Auto-GPT from GitHub and prepares the installer
# Fixed version with better error handling and branch detection

# Ensure we stop on error
$ErrorActionPreference = "Stop"

# Banner
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "      Auto-GPT Windows Installer Builder (Fixed)     " -ForegroundColor Cyan
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
    # Try alternate paths
    $alternatePaths = @(
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 5\ISCC.exe"
    )
    
    foreach ($path in $alternatePaths) {
        if (Test-Path $path) {
            $innoSetupPath = $path
            Write-Host "Found Inno Setup at alternative path: $innoSetupPath" -ForegroundColor Green
            break
        }
    }
    
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
            Write-Host "Please download and install Inno Setup manually from: https://jrsoftware.org/isdl.php" -ForegroundColor Yellow
            exit 1
        }
        
        # Install Inno Setup silently
        Write-Host "Installing Inno Setup..." -ForegroundColor Yellow
        Start-Process -FilePath $innoSetupInstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait
        
        # Check if installation succeeded
        if (-not (Test-Path $innoSetupPath)) {
            Write-Host "Failed to install Inno Setup. Please install it manually." -ForegroundColor Red
            exit 1
        }
        
        Write-Host "Inno Setup installed successfully." -ForegroundColor Green
    }
}

# Function to check if the original repo is available and clone it
function Clone-Repository {
    param (
        [string]$RepoUrl,
        [string]$OutputDir
    )
    
    Write-Host "Trying to clone from $RepoUrl..." -ForegroundColor Yellow
    
    # Check if git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is not installed. Installing Git..." -ForegroundColor Yellow
        $gitInstallerUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
        $gitInstaller = Join-Path $tempDir "git-installer.exe"
        
        try {
            Invoke-WebRequest -Uri $gitInstallerUrl -OutFile $gitInstaller
            Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT /NORESTART" -Wait
            # Add Git to PATH for current session
            $env:PATH = "$env:PATH;C:\Program Files\Git\cmd"
        }
        catch {
            Write-Host "Failed to install Git. Please install it manually." -ForegroundColor Red
            exit 1
        }
    }
    
    # Try different branches
    $branches = @("stable", "main", "master")
    $cloneSuccess = $false
    
    foreach ($branch in $branches) {
        try {
            Write-Host "Attempting to clone branch: $branch" -ForegroundColor Yellow
            git clone -b $branch $RepoUrl $OutputDir 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully cloned branch: $branch" -ForegroundColor Green
                $cloneSuccess = $true
                break
            }
        }
        catch {
            Write-Host "Failed to clone branch $branch: $_" -ForegroundColor Yellow
        }
    }
    
    if (-not $cloneSuccess) {
        # Try cloning without specifying a branch
        try {
            Write-Host "Attempting to clone without specifying a branch..." -ForegroundColor Yellow
            git clone $RepoUrl $OutputDir 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully cloned repository (default branch)" -ForegroundColor Green
                $cloneSuccess = $true
            }
        }
        catch {
            Write-Host "Failed to clone repository: $_" -ForegroundColor Red
        }
    }
    
    return $cloneSuccess
}

# Try to clone the repository
$repoDir = Join-Path $tempDir "autogpt_repo"
$cloneSuccess = Clone-Repository -RepoUrl "https://github.com/Significant-Gravitas/Auto-GPT.git" -OutputDir $repoDir

if (-not $cloneSuccess) {
    # As a fallback, try to use local files
    Write-Host "Failed to clone from GitHub. Trying to use local files..." -ForegroundColor Yellow
    
    $scriptRoot = Split-Path -Parent -Path $PSCommandPath
    $repoRoot = Split-Path -Parent -Path (Split-Path -Parent -Path $scriptRoot)
    
    if (Test-Path (Join-Path $repoRoot ".env.template")) {
        Write-Host "Using local repository at: $repoRoot" -ForegroundColor Green
        New-Item -ItemType Directory -Path $repoDir -Force | Out-Null
        
        # Copy necessary files from local repo
        Copy-Item -Path (Join-Path $repoRoot ".env.template") -Destination $tempDir
        Copy-Item -Path (Join-Path $repoRoot "autogpt") -Destination $repoDir -Recurse -Force
        Copy-Item -Path (Join-Path $repoRoot "requirements.txt") -Destination $repoDir -Force
    }
    else {
        Write-Host "Could not find a local repository with Auto-GPT files." -ForegroundColor Red
        Write-Host "Please download Auto-GPT manually from: https://github.com/Significant-Gravitas/Auto-GPT" -ForegroundColor Yellow
        exit 1
    }
}

# Search for .env.template in various possible locations
$envTemplateSearch = @(
    (Join-Path $repoDir ".env.template"),
    (Join-Path $repoDir "autogpt" ".env.template"),
    (Join-Path $repoDir ".env.example"),
    (Join-Path $repoDir "autogpt" ".env.example")
)

$envTemplatePath = $null
foreach ($path in $envTemplateSearch) {
    if (Test-Path $path) {
        $envTemplatePath = $path
        Write-Host "Found environment template at: $envTemplatePath" -ForegroundColor Green
        break
    }
}

if ($envTemplatePath) {
    # Copy .env template to the temp directory
    Copy-Item -Path $envTemplatePath -Destination (Join-Path $tempDir ".env.template")
}
else {
    # Create a minimal .env template as fallback
    Write-Host "No .env template found. Creating a minimal template..." -ForegroundColor Yellow
    @"
# Auto-GPT Configuration File
OPENAI_API_KEY=your-openai-api-key

# Optional configurations
TEMPERATURE=0
EXECUTE_LOCAL_COMMANDS=False
RESTRICT_TO_WORKSPACE=True

# Uncomment and set API keys for additional features
# GOOGLE_API_KEY=your-google-api-key
# GITHUB_API_KEY=your-github-api-key
# PINECONE_API_KEY=your-pinecone-api-key
"@ | Out-File -FilePath (Join-Path $tempDir ".env.template") -Encoding UTF8
}

# Download or create icon
$iconPath = Join-Path $tempDir "auto_gpt_icon.ico"
try {
    # Try to find icon in repository first
    $possibleIconPaths = @(
        (Join-Path $repoDir "autogpt" "app" "web" "static" "favicon.ico"),
        (Join-Path $repoDir "favicon.ico"),
        (Join-Path $repoDir "icon.ico"),
        (Join-Path $repoDir "logo.ico")
    )
    
    $foundIcon = $false
    foreach ($path in $possibleIconPaths) {
        if (Test-Path $path) {
            Copy-Item -Path $path -Destination $iconPath
            $foundIcon = $true
            Write-Host "Found icon in repository: $path" -ForegroundColor Green
            break
        }
    }
    
    if (-not $foundIcon) {
        # Try to download icon from GitHub
        Write-Host "No icon found in repository. Downloading from GitHub..." -ForegroundColor Yellow
        $iconUrl = "https://raw.githubusercontent.com/Significant-Gravitas/Auto-GPT/master/autogpt/app/web/static/favicon.ico"
        Invoke-WebRequest -Uri $iconUrl -OutFile $iconPath
    }
}
catch {
    Write-Host "Failed to get icon. Creating a placeholder..." -ForegroundColor Yellow
    
    # As a fallback, we'll use PowerShell to create a simple .ico file
    Add-Type -AssemblyName System.Drawing
    $bitmap = New-Object System.Drawing.Bitmap 32, 32
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::Blue)
    $bitmap.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Icon)
    $graphics.Dispose()
    $bitmap.Dispose()
}

# Copy scripts from the current script directory
$scriptSource = Join-Path (Split-Path -Parent -Path $PSCommandPath) "*.*"
Copy-Item -Path $scriptSource -Destination $tempDir

# Create installer images if they don't exist
$installerImagePath = Join-Path $tempDir "installer_image.bmp"
$installerSmallImagePath = Join-Path $tempDir "installer_small.bmp"

if (-not (Test-Path $installerImagePath)) {
    # Create a simple image for the installer
    try {
        Add-Type -AssemblyName System.Drawing
        $bitmap = New-Object System.Drawing.Bitmap 500, 314
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::White)
        
        $font = New-Object System.Drawing.Font("Arial", 24, [System.Drawing.FontStyle]::Bold)
        $brush = [System.Drawing.Brushes]::Blue
        $graphics.DrawString("Auto-GPT", $font, $brush, 150, 120)
        
        $font = New-Object System.Drawing.Font("Arial", 12)
        $graphics.DrawString("Autonomous AI Agent", $font, $brush, 170, 170)
        
        $bitmap.Save($installerImagePath, [System.Drawing.Imaging.ImageFormat]::Bmp)
        $graphics.Dispose()
        $bitmap.Dispose()
        
        # Create small image
        $bitmap = New-Object System.Drawing.Bitmap 55, 55
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::White)
        
        $font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
        $graphics.DrawString("A", $font, $brush, 20, 15)
        
        $bitmap.Save($installerSmallImagePath, [System.Drawing.Imaging.ImageFormat]::Bmp)
        $graphics.Dispose()
        $bitmap.Dispose()
    }
    catch {
        Write-Host "Failed to create installer images. Continuing without them..." -ForegroundColor Yellow
    }
}

# Create the installer
Write-Host "Creating installer..." -ForegroundColor Yellow
$innoScriptPath = Join-Path $tempDir "auto_gpt_setup.iss"

# Update the Inno Setup script to handle missing image files
if (Test-Path $innoScriptPath) {
    $innoScript = Get-Content -Path $innoScriptPath -Raw
    
    # Remove references to image files if they don't exist
    if (-not (Test-Path $installerImagePath)) {
        $innoScript = $innoScript -replace "WizardImageFile=installer_image.bmp", ""
    }
    
    if (-not (Test-Path $installerSmallImagePath)) {
        $innoScript = $innoScript -replace "WizardSmallImageFile=installer_small.bmp", ""
    }
    
    # Write updated script
    Set-Content -Path $innoScriptPath -Value $innoScript
}

# Run Inno Setup compiler
try {
    & $innoSetupPath $innoScriptPath
    
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup compilation failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Host "Failed to create installer: $_" -ForegroundColor Red
    Write-Host "You can try to compile the installer manually using Inno Setup Compiler." -ForegroundColor Yellow
    Write-Host "The script is located at: $innoScriptPath" -ForegroundColor Yellow
    exit 1
}

# Check if the installer was created successfully
$installerPath = Join-Path $tempDir "Auto-GPT_Setup.exe"
if (Test-Path $installerPath) {
    # Copy to the desktop for ease of access
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $finalInstallerPath = Join-Path $desktopPath "Auto-GPT_Setup.exe"
    Copy-Item -Path $installerPath -Destination $finalInstallerPath
    
    # Also copy to the current directory
    $currentDirInstaller = Join-Path (Get-Location).Path "Auto-GPT_Setup.exe"
    if ((Get-Location).Path -ne $tempDir) {
        Copy-Item -Path $installerPath -Destination $currentDirInstaller
    }
    
    Write-Host "=====================================================" -ForegroundColor Green
    Write-Host "Installer created successfully!" -ForegroundColor Green
    Write-Host "Location 1: $finalInstallerPath" -ForegroundColor Green
    Write-Host "Location 2: $currentDirInstaller" -ForegroundColor Green
    Write-Host "=====================================================" -ForegroundColor Green
}
else {
    Write-Host "Failed to create installer." -ForegroundColor Red
    exit 1
}

# Cleanup - keep the temp directory for debugging
Write-Host "Temporary files are at: $tempDir" -ForegroundColor Yellow
Write-Host "You can delete this directory manually once you've verified the installer works." -ForegroundColor Yellow

Write-Host "Done!" -ForegroundColor Green
