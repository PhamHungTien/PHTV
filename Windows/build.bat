@echo on
setlocal

:: Switch to script directory
cd /d "%~dp0"

echo [0/3] Stopping PHTV.exe if running...
taskkill /F /IM PHTV.exe 2>nul

echo [1/3] Cleaning previous build...
if exist build rmdir /s /q build
mkdir build

echo [2/3] Building C++ Core (PHTVCore.dll)...
cd build
:: CMakeLists.txt is in the parent directory (Windows/)
cmake -G "Visual Studio 17 2022" -A x64 ..
cmake --build . --config Release
cd ..

if not exist "build\Release\PHTVCore.dll" (
    echo [ERROR] Failed to build PHTVCore.dll
    pause
    exit /b 1
)

set MODE=lite
if /I "%1"=="full" set MODE=full

set PUBLISH_SINGLE_FILE=false
set SELF_CONTAINED=false
set INCLUDE_NATIVE=false

if /I "%MODE%"=="full" (
    set PUBLISH_SINGLE_FILE=true
    set SELF_CONTAINED=true
    set INCLUDE_NATIVE=true
)

echo [3/3] Building %MODE% package (PHTV.exe)...
:: PHTV.UI.csproj is in UI/
dotnet publish UI/PHTV.UI.csproj -c Release -r win-x64 /p:PublishSingleFile=%PUBLISH_SINGLE_FILE% /p:IncludeNativeLibrariesForSelfExtract=%INCLUDE_NATIVE% --self-contained %SELF_CONTAINED% -o build/Release

if %errorlevel% neq 0 (
    echo [ERROR] Dotnet publish failed!
    pause
    exit /b 1
)

echo ========================================================
echo   BUILD SUCCESS!
echo   Output directory: %CD%\build\Release
echo   Run the app: %CD%\build\Release\PHTV.exe
echo   Build mode: %MODE%
echo ========================================================
pause
