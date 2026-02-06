add_library(phtv_engine_shared STATIC
    Engine/ConvertTool.cpp
    Engine/Engine.cpp
    Engine/EnglishWordDetector.cpp
    Engine/Macro.cpp
    Engine/SmartSwitchKey.cpp
    Engine/Vietnamese.cpp
)

target_include_directories(phtv_engine_shared
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/Engine
        ${CMAKE_CURRENT_SOURCE_DIR}/Platforms
)

target_compile_features(phtv_engine_shared PUBLIC cxx_std_17)

if (WIN32)
    target_compile_definitions(phtv_engine_shared PUBLIC _CRT_SECURE_NO_WARNINGS NOMINMAX)
endif()
