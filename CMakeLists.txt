cmake_minimum_required(VERSION 3.20)
project(PHTV LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(PHTV_BUILD_WINDOWS_FOUNDATION "Build Windows IME foundation targets" ON)
option(PHTV_BUILD_LINUX_FOUNDATION "Build Linux IME foundation targets" ON)

add_subdirectory(Shared)

if (WIN32 AND PHTV_BUILD_WINDOWS_FOUNDATION)
    add_subdirectory(Windows)
endif()

if (UNIX AND NOT APPLE AND PHTV_BUILD_LINUX_FOUNDATION)
    add_subdirectory(Linux)
endif()
