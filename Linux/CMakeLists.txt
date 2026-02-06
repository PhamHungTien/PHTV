add_library(phtv_linux_runtime STATIC
    Runtime/EngineGlobals.cpp
)

target_include_directories(phtv_linux_runtime
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/Runtime
        ${CMAKE_SOURCE_DIR}/Shared/Engine
        ${CMAKE_SOURCE_DIR}/Shared/Platforms
)

target_link_libraries(phtv_linux_runtime
    PUBLIC
        phtv_engine_shared
)

add_library(phtv_linux_adapter STATIC
    Adapter/LinuxKeycodeAdapter.cpp
)

target_include_directories(phtv_linux_adapter
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/Adapter
        ${CMAKE_SOURCE_DIR}/Shared/Engine
)

add_library(phtv_linux_host STATIC
    Host/PHTVEngineSession.cpp
)

target_include_directories(phtv_linux_host
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/Host
        ${CMAKE_CURRENT_SOURCE_DIR}/Runtime
        ${CMAKE_SOURCE_DIR}/Shared/Engine
)

target_link_libraries(phtv_linux_host
    PUBLIC
        phtv_engine_shared
        phtv_linux_runtime
)

add_library(phtv_linux_ibus STATIC
    IBus/PHTVIBusEngineSkeleton.cpp
)

target_include_directories(phtv_linux_ibus
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/IBus
        ${CMAKE_CURRENT_SOURCE_DIR}/Host
)

target_link_libraries(phtv_linux_ibus
    PUBLIC
        phtv_linux_host
        phtv_linux_adapter
)

add_executable(phtv_linux_console
    Host/ConsoleSmokeMain.cpp
)

target_link_libraries(phtv_linux_console
    PRIVATE
        phtv_linux_host
        phtv_linux_adapter
)
