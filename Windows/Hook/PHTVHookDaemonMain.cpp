#ifdef _WIN32

#include <windows.h>
#include <cstdio>
#include <filesystem>
#include <io.h>
#include <iostream>

#include "DictionaryBootstrap.h"
#include "EngineGlobals.h"
#include "LowLevelHookService.h"
#include "RuntimeConfig.h"

namespace {

phtv::windows_hook::LowLevelHookService* g_service = nullptr;
FILE* g_logFile = nullptr;

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

void openLogFile() {
    try {
        auto logDir = phtv::windows_runtime::runtimeDirectory();
        std::error_code ec;
        std::filesystem::create_directories(logDir, ec);
        auto logPath = logDir / "phtv-daemon.log";
        g_logFile = _wfopen(logPath.wstring().c_str(), L"a");
        if (g_logFile != nullptr) {
            // Redirect both stdout and stderr to the log file so that all
            // existing std::cerr / std::cout calls are captured even when the
            // daemon runs without a console window (CreateNoWindow=true).
            _dup2(_fileno(g_logFile), _fileno(stdout));
            _dup2(_fileno(g_logFile), _fileno(stderr));
            setvbuf(stdout, nullptr, _IONBF, 0);
            setvbuf(stderr, nullptr, _IONBF, 0);
        }
    } catch (...) {
        // Logging is best-effort; if it fails, continue without it.
    }
}

void closeLogFile() {
    if (g_logFile != nullptr) {
        std::fflush(g_logFile);
        std::fclose(g_logFile);
        g_logFile = nullptr;
    }
}

} // namespace

int main() {
    openLogFile();

    phtv::windows_runtime::resetEngineDefaults();
    const auto dictionaryStatus = phtv::windows_runtime::ensureDictionariesLoaded();

    std::cerr << "[PHTV] Daemon starting. Dictionary load status - EN: "
              << (dictionaryStatus.englishLoaded ? "ok" : "missing")
              << ", VI: "
              << (dictionaryStatus.vietnameseLoaded ? "ok" : "missing")
              << "\n";

    phtv::windows_hook::LowLevelHookService service;
    g_service = &service;

    SetConsoleCtrlHandler(consoleCtrlHandler, TRUE);

    if (!service.start()) {
        std::cerr << "[PHTV] Failed to install low-level keyboard/mouse hooks.\n";
        closeLogFile();
        return 1;
    }

    std::cerr << "[PHTV] Hook daemon is running.\n";
    int result = service.runMessageLoop();
    std::cerr << "[PHTV] Hook daemon exiting.\n";
    closeLogFile();
    return result;
}

#endif // _WIN32
