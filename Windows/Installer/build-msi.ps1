# PHTV MSI Builder Script
# Requires WiX Toolset v3.11+ installed on Windows

[CmdletBinding()]
param(
    [string]$Runtime = "win-x64",
    [string]$ProductVersion = "1.0.0"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-NativeOrThrow {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $FilePath $($Arguments -join ' ')"
    }
}

function Resolve-WixToolPath {
    param([Parameter(Mandatory = $true)][string]$ToolName)

    $command = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    $defaultPath = Join-Path "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin" $ToolName
    if (Test-Path $defaultPath) {
        return $defaultPath
    }

    throw "Cannot find $ToolName. Install WiX Toolset v3.11 and ensure it is on PATH."
}

function Assert-UpgradeCodeIsValid {
    param([Parameter(Mandatory = $true)][string]$WxsPath)

    $content = Get-Content -Path $WxsPath -Raw
    $match = [regex]::Match($content, '<\?define\s+UpgradeCode\s*=\s*"([^"]+)"\s*\?>')
    if (-not $match.Success) {
        throw "Cannot find '<?define UpgradeCode = \"...\" ?>' in $WxsPath"
    }

    $upgradeCode = $match.Groups[1].Value
    $guidPattern = '^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$'
    if ($upgradeCode -notmatch $guidPattern) {
        throw "UpgradeCode '$upgradeCode' is not a legal GUID. Use format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."
    }
}

function Assert-ProductVersionIsValid {
    param([Parameter(Mandatory = $true)][string]$Version)

    if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "ProductVersion '$Version' is invalid. Expected format: major.minor.build (e.g., 1.0.42)."
    }

    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $build = [int]$Matches[3]

    if ($major -lt 0 -or $major -gt 255) {
        throw "ProductVersion major '$major' is out of range (0..255)."
    }

    if ($minor -lt 0 -or $minor -gt 255) {
        throw "ProductVersion minor '$minor' is out of range (0..255)."
    }

    if ($build -lt 0 -or $build -gt 65535) {
        throw "ProductVersion build '$build' is out of range (0..65535)."
    }
}

$InstallerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $InstallerDir "..\..")).Path
$PublishDir = Join-Path $ProjectRoot "Windows\App\publish\$Runtime"
$SourceDir = Join-Path $InstallerDir "Source"
$WxsPath = Join-Path $InstallerDir "PHTV.wxs"
$WixObjPath = Join-Path $InstallerDir "PHTV.wixobj"
$MsiPath = Join-Path $InstallerDir "PHTV-Setup.msi"

Write-Host "--- PHTV MSI BUILDER ---" -ForegroundColor Cyan
Write-Host "ProjectRoot: $ProjectRoot"
Write-Host "PublishDir:  $PublishDir"
Write-Host "MSI Version: $ProductVersion"

Assert-ProductVersionIsValid -Version $ProductVersion

if (-not (Test-Path $WxsPath)) {
    throw "Missing WiX source file: $WxsPath"
}

Assert-UpgradeCodeIsValid -WxsPath $WxsPath

if (-not (Test-Path $PublishDir)) {
    throw "Publish directory not found: $PublishDir"
}

$publishExe = Join-Path $PublishDir "PHTV.exe"
if (-not (Test-Path $publishExe)) {
    throw "Missing executable: $publishExe"
}

$publishDictionaries = Join-Path $PublishDir "Dictionaries"
if (-not (Test-Path $publishDictionaries)) {
    throw "Missing Dictionaries directory: $publishDictionaries"
}

$requiredDictionaryFiles = @(
    (Join-Path $publishDictionaries "en_dict.bin"),
    (Join-Path $publishDictionaries "vi_dict.bin")
)
foreach ($dictionaryFile in $requiredDictionaryFiles) {
    if (-not (Test-Path $dictionaryFile)) {
        throw "Missing required dictionary file: $dictionaryFile"
    }
}

# Ensure installer icon exists.
$installerAssetsDir = Join-Path $InstallerDir "Assets"
if (-not (Test-Path $installerAssetsDir)) {
    New-Item -ItemType Directory -Path $installerAssetsDir | Out-Null
}

$installerIconPath = Join-Path $installerAssetsDir "icon.ico"
$iconCandidates = @(
    (Join-Path $ProjectRoot "Windows\App\Assets\PHTV.ico"),
    (Join-Path $ProjectRoot "Windows\App\Assets\icon.ico"),
    (Join-Path $ProjectRoot "docs\images\icon.ico")
)

if (-not (Test-Path $installerIconPath)) {
    foreach ($candidate in $iconCandidates) {
        if (Test-Path $candidate) {
            Copy-Item -Path $candidate -Destination $installerIconPath -Force
            break
        }
    }
}

if (-not (Test-Path $installerIconPath)) {
    throw "Missing icon.ico for installer. Expected at $installerIconPath"
}

# Prepare Source folder consumed by WiX.
if (Test-Path $SourceDir) {
    Remove-Item $SourceDir -Recurse -Force
}
New-Item -ItemType Directory -Path $SourceDir | Out-Null

Write-Host "Preparing source files from $PublishDir..."
Copy-Item -Path $publishExe -Destination $SourceDir -Force
Copy-Item -Path $publishDictionaries -Destination $SourceDir -Recurse -Force

$candleExe = Resolve-WixToolPath -ToolName "candle.exe"
$lightExe = Resolve-WixToolPath -ToolName "light.exe"

Write-Host "Compiling WiX source..."
Invoke-NativeOrThrow -FilePath $candleExe -Arguments @(
    "-nologo",
    "-dProductVersion=$ProductVersion",
    "-out", $WixObjPath,
    $WxsPath,
    "-ext", "WixUIExtension",
    "-ext", "WixUtilExtension"
)

if (-not (Test-Path $WixObjPath)) {
    throw "Expected output not found: $WixObjPath"
}

Write-Host "Linking MSI package..."
Invoke-NativeOrThrow -FilePath $lightExe -Arguments @(
    "-nologo",
    "-out", $MsiPath,
    $WixObjPath,
    "-ext", "WixUIExtension",
    "-ext", "WixUtilExtension",
    "-cultures:vi-VN;en-US"
)

if (-not (Test-Path $MsiPath)) {
    throw "MSI build finished but output file was not found: $MsiPath"
}

Write-Host "Done! Installer created at: $MsiPath" -ForegroundColor Green
