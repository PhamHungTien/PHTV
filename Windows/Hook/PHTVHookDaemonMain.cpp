#ifdef _WIN32

#include <windows.h>
#include <iostream>

#include "DictionaryBootstrap.h"
#include "EngineGlobals.h"
#include "LowLevelHookService.h"

namespace {

phtv::windows_hook::LowLevelHookService* g_service = nullptr;

BOOL WINAPI consoleCtrlHandler(DWORD signal) {
    switch (signal) {
        case CTRL_C_EVENT:
        case CTRL_BREAK_EVENT:
        case CTRL_CLOSE_EVENT:
        case CTRL_LOGOFF_EVENT:
        case CTRL_SHUTDOWN_EVENT:
            if (g_service != nullptr) {
                g_service->stop();
            }
            return TRUE;
        default:
            return FALSE;
    }
}

} // namespace

int main() {
    phtv::windows_runtime::resetEngineDefaults();
    const auto dictionaryStatus = phtv::windows_runtime::ensureDictionariesLoaded();

    std::cout << "Dictionary load status - EN: "
              << (dictionaryStatus.englishLoaded ? "ok" : "missing")
              << ", VI: "
              << (dictionaryStatus.vietnameseLoaded ? "ok" : "missing")
              << "\n";

    phtv::windows_hook::LowLevelHookService service;
    g_service = &service;

    SetConsoleCtrlHandler(consoleCtrlHandler, TRUE);

    if (!service.start()) {
        std::cerr << "Failed to install low-level keyboard/mouse hooks.\n";
        return 1;
    }

    std::cout << "PHTV hook daemon is running.\n";
    std::cout << "Press Ctrl+C to stop.\n";
    return service.runMessageLoop();
}

#endif // _WIN32
