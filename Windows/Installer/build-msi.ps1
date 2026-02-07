# PHTV MSI Builder Script
# Requires WiX Toolset v3.11+ installed on Windows

$ErrorActionPreference = "Stop"

$InstallerDir = Split-Path $MyInvocation.MyCommand.Path
$ProjectRoot = (Get-Item $InstallerDir).Parent.Parent.FullName
$PublishDir = Join-Path $ProjectRoot "Windows\App\publish\win-x64"
$SourceDir = Join-Path $InstallerDir "Source"

Write-Host "--- PHTV MSI BUILDER ---" -ForegroundColor Cyan

# 1. Clean and Prepare Source
if (Test-Path $SourceDir) { Remove-Item $SourceDir -Recurse -Force }
New-Item -ItemType Directory -Path $SourceDir | Out-Null
Write-Host "Preparing source files from $PublishDir..."

# Copy main files
Copy-Item (Join-Path $PublishDir "PHTV.exe") $SourceDir
Copy-Item (Join-Path $PublishDir "Dictionaries") $SourceDir -Recurse

# 2. Build MSI using WiX
Write-Host "Compiling WiX source..."
& candle.exe -nologo -out "$InstallerDir\PHTV.wixobj" "$InstallerDir\PHTV.wxs" -ext WixUIExtension -ext WixUtilExtension

WriteHost "Linking MSI package..."
& light.exe -nologo -out "$InstallerDir\PHTV-Setup.msi" "$InstallerDir\PHTV.wixobj" -ext WixUIExtension -ext WixUtilExtension "-cultures:vi-VN;en-US"

Write-Host "Done! Installer created at: $InstallerDir\PHTV-Setup.msi" -ForegroundColor Green
