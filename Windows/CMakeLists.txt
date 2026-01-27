cmake_minimum_required(VERSION 3.10)
project(PHTV_Win LANGUAGES C CXX)

# Use C++17 standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Source files from Core Engine
file(GLOB_RECURSE CORE_SOURCES
    "Core/Engine/*.cpp"
    "Core/Config/*.m" # Config uses Objective-C style implementation but on Windows we might need to adapt or exclude if pure C++
)

# Note: PHTVConfig.m is likely Objective-C and won't compile with MSVC C++.
# We need to ensure we only include C++ compatible files or provide a Windows implementation (PHTVConfig.cpp).
# For now, let's include the Engine cpp files which seem to be C++.

set(ENGINE_SOURCES
    "Engine/Engine.cpp"
    "Engine/Vietnamese.cpp"
    "Engine/Macro.cpp"
    "Engine/EnglishWordDetector.cpp"
    "Engine/ConvertTool.cpp"
    "Engine/SmartSwitchKey.cpp"
    "Config/PHTVConfig.cpp"
)

# App Sources
set(APP_SOURCES
    "App/main.cpp"
)

# Create Windows Executable (GUI application, not Console)
add_executable(PHTV WIN32
    ${ENGINE_SOURCES}
    ${APP_SOURCES}
)

# Definitions
target_compile_definitions(PHTV PRIVATE _WIN32 UNICODE _UNICODE)

if(MINGW)
    target_link_options(PHTV PRIVATE -municode)
endif()

# Include Directories
target_include_directories(PHTV PRIVATE
    "Engine"
    "Config"
    "Platforms"
    "App"
)

# Link Libraries
target_link_libraries(PHTV PRIVATE
    user32
    kernel32
    gdi32
    shell32
    shlwapi
)
