@echo on
setlocal

echo [0/3] Stopping PHTV.exe if running...
taskkill /F /IM PHTV.exe 2>nul
taskkill /F /IM PHTV_Legacy.exe 2>nul

echo [1/3] Cleaning previous build...
if exist build_win rmdir /s /q build_win
mkdir build_win

echo [2/3] Building C++ Core (PHTVCore.dll)...
cd build_win
cmake -G "Visual Studio 17 2022" -A x64 ..\Windows
cmake --build . --config Release
cd ..

if not exist "build_win\Release\PHTVCore.dll" (
    echo [ERROR] Failed to build PHTVCore.dll
    pause
    exit /b 1
)

echo [3/3] Building Single File EXE (PHTV.exe)...
dotnet publish Windows/UI/PHTV.UI.csproj -c Release -r win-x64 /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true --self-contained true -o build_win/Release

if %errorlevel% neq 0 (
    echo [ERROR] Dotnet publish failed!
    pause
    exit /b 1
)

echo ========================================================
echo   BUILD SUCCESS!
echo   Output directory: %CD%\build_win\Release
echo   Run the app: %CD%\build_win\Release\PHTV.exe
echo ========================================================
pause
