cmake_minimum_required(VERSION 3.10)
project(PHTV_Win LANGUAGES C CXX)

# Use C++17 standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Shared engine source (single source of truth)
set(ENGINE_DIR "${CMAKE_CURRENT_LIST_DIR}/../Engine")
set(PLATFORMS_DIR "${CMAKE_CURRENT_LIST_DIR}/../Platforms")

set(ENGINE_SOURCES
    "${ENGINE_DIR}/Engine.cpp"
    "${ENGINE_DIR}/Vietnamese.cpp"
    "${ENGINE_DIR}/Macro.cpp"
    "${ENGINE_DIR}/EnglishWordDetector.cpp"
    "${ENGINE_DIR}/ConvertTool.cpp"
    "${ENGINE_DIR}/SmartSwitchKey.cpp"
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
    "${ENGINE_DIR}"
    "${PLATFORMS_DIR}"
    "Config"
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
