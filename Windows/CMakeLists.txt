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

set(DLL_SOURCES
    "Bridge.cpp"
    ${ENGINE_SOURCES}
)

set(APP_SOURCES
    "App/main.cpp"
    "App/PHTV.rc"
)
# Definitions
add_compile_definitions(_WIN32 UNICODE _UNICODE)

if(MSVC)
    # Use static runtime to avoid missing DLL dependencies
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    
    # Avoid std::byte conflict with Windows SDK headers (rpcndr.h/wtypes.h).
    add_compile_definitions(_HAS_STD_BYTE=0)
endif()

if(MINGW)
    add_link_options(-municode -static -static-libgcc -static-libstdc++)
endif()

# Include Directories
include_directories(
    "${ENGINE_DIR}"
    "${PLATFORMS_DIR}"
    "Config"
)

# Build Core DLL
add_library(PHTVCore SHARED
    ${DLL_SOURCES}
)

target_compile_definitions(PHTVCore PRIVATE PHTV_EXPORTS)

target_include_directories(PHTVCore PRIVATE
    "${ENGINE_DIR}"
    "${PLATFORMS_DIR}"
    "Config"
)

target_link_libraries(PHTVCore PRIVATE
    user32
    kernel32
    gdi32
    shell32
    shlwapi
)
