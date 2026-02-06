function(phtv_configure_mingw_runtime target_name)
    if(MINGW)
        target_link_options(${target_name}
            PRIVATE
                -static-libgcc
                -static-libstdc++
                -Wl,-Bstatic
                -lwinpthread
                -Wl,-Bdynamic
        )
    endif()
endfunction()

add_library(phtv_windows_runtime STATIC
    Runtime/DictionaryBootstrap.cpp
    Runtime/EngineGlobals.cpp
    Runtime/RuntimeConfig.cpp
)

target_include_directories(phtv_windows_runtime
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/Runtime
        ${CMAKE_SOURCE_DIR}/Shared/Engine
)

target_link_libraries(phtv_windows_runtime
    PUBLIC
        phtv_engine_shared
)

add_library(phtv_windows_adapter STATIC
    Adapter/Win32KeycodeAdapter.cpp
)

target_include_directories(phtv_windows_adapter
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/Adapter
        ${CMAKE_SOURCE_DIR}/Shared/Engine
)

add_library(phtv_windows_host STATIC
    Host/PHTVEngineSession.cpp
)

target_include_directories(phtv_windows_host
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/Host
        ${CMAKE_CURRENT_SOURCE_DIR}/Runtime
        ${CMAKE_SOURCE_DIR}/Shared/Engine
)

target_link_libraries(phtv_windows_host
    PUBLIC
        phtv_engine_shared
        phtv_windows_runtime
)

add_library(phtv_windows_hook STATIC
    Hook/LowLevelHookService.cpp
)

target_include_directories(phtv_windows_hook
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/Hook
        ${CMAKE_CURRENT_SOURCE_DIR}/Host
        ${CMAKE_CURRENT_SOURCE_DIR}/Runtime
        ${CMAKE_CURRENT_SOURCE_DIR}/Adapter
        ${CMAKE_SOURCE_DIR}/Shared/Engine
)

target_link_libraries(phtv_windows_hook
    PUBLIC
        phtv_windows_host
        phtv_windows_adapter
        user32
        ole32
        oleaut32
        uiautomationcore
        uuid
)

add_executable(phtv_windows_console
    Host/ConsoleSmokeMain.cpp
)
phtv_configure_mingw_runtime(phtv_windows_console)

target_link_libraries(phtv_windows_console
    PRIVATE
        phtv_windows_host
        phtv_windows_adapter
)

add_executable(phtv_windows_hook_daemon
    Hook/PHTVHookDaemonMain.cpp
)
phtv_configure_mingw_runtime(phtv_windows_hook_daemon)

target_link_libraries(phtv_windows_hook_daemon
    PRIVATE
        phtv_windows_hook
)
