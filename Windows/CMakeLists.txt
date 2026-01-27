cmake_minimum_required(VERSION 3.10)
project(PHTV_Win LANGUAGES C CXX)

# Use C++17 standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(ENGINE_SOURCES
    "Engine/Engine.cpp"
    "Engine/Vietnamese.cpp"
    "Engine/Macro.cpp"
    "Engine/EnglishWordDetector.cpp"
    "Engine/ConvertTool.cpp"
    "Engine/SmartSwitchKey.cpp"
    "Config/PHTVConfig.cpp"
)

set(APP_SOURCES
    "App/main.cpp"
    "App/PHTV.rc"
)

# Definitions
add_compile_definitions(_WIN32 UNICODE _UNICODE)

if(MINGW)
    add_link_options(-municode -static -static-libgcc -static-libstdc++)
endif()

# Include Directories
include_directories(
    "Engine"
    "Config"
    "Platforms"
    "App"
)

# Build EXE
add_executable(PHTV WIN32
    ${ENGINE_SOURCES}
    ${APP_SOURCES}
)

# Link Libraries
target_link_libraries(PHTV PRIVATE
    user32
    kernel32
    gdi32
    shell32
    shlwapi
    comctl32
    msimg32
)
