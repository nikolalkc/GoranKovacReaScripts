# Script to copy ReaSpaghetti folder from source to destination with overwrite
# Reads paths from local config file

param(
    [string]$ConfigPath = "copy-config.json"
)

# Read config file
if (-not (Test-Path $ConfigPath)) {
    Write-Host "Error: Config file not found at $ConfigPath" -ForegroundColor Red
    exit 1
}

try {
    $config = Get-Content $ConfigPath | ConvertFrom-Json
}
catch {
    Write-Host "Error: Failed to parse config file: $_" -ForegroundColor Red
    exit 1
}

$sourceFolder = $config.sourceFolder
$destinationFolder = $config.destinationFolder

# Validate source folder exists
if (-not (Test-Path $sourceFolder)) {
    Write-Host "Error: Source folder not found: $sourceFolder" -ForegroundColor Red
    exit 1
}

Write-Host "Copying ReaSpaghetti folder..." -ForegroundColor Green
Write-Host "From: $sourceFolder"
Write-Host "To:   $destinationFolder"
Write-Host ""

try {
    # Copy folder with overwrite (Remove destination first if it exists, then copy)
    if (Test-Path $destinationFolder) {
        Write-Host "Destination folder exists. Removing old version..." -ForegroundColor Yellow
        Remove-Item $destinationFolder -Recurse -Force
    }
    
    # Create parent directory if needed
    $parentPath = Split-Path $destinationFolder
    if (-not (Test-Path $parentPath)) {
        New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
    }
    
    # Copy the folder (excluding .gitignore files)
    Copy-Item -Path $sourceFolder -Destination $destinationFolder -Recurse -Force -Exclude ".gitignore"
    
    Write-Host "Successfully copied ReaSpaghetti folder!" -ForegroundColor Green
}
catch {
    Write-Host "Error: Failed to copy folder: $_" -ForegroundColor Red
    exit 1
}
