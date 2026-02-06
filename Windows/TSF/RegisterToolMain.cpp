#ifdef _WIN32

#include <windows.h>
#include <iostream>
#include <string>

namespace {

using DllRegisterServerFn = HRESULT(STDAPICALLTYPE*)();

std::string toAbsolutePath(const std::string& path) {
    if (path.empty()) {
        return path;
    }

    char fullPath[MAX_PATH] = {};
    const DWORD written = GetFullPathNameA(path.c_str(),
                                           static_cast<DWORD>(std::size(fullPath)),
                                           fullPath,
                                           nullptr);
    if (written == 0 || written >= std::size(fullPath)) {
        return path;
    }

    return std::string(fullPath, fullPath + written);
}

std::string defaultTsfDllPath() {
    char modulePath[MAX_PATH] = {};
    const DWORD length = GetModuleFileNameA(nullptr,
                                            modulePath,
                                            static_cast<DWORD>(std::size(modulePath)));
    if (length == 0 || length >= std::size(modulePath)) {
        return "phtv_windows_tsf.dll";
    }

    std::string fullPath(modulePath, modulePath + length);
    const size_t lastSlash = fullPath.find_last_of("\\/");
    if (lastSlash == std::string::npos) {
        return "phtv_windows_tsf.dll";
    }

    return fullPath.substr(0, lastSlash + 1) + "phtv_windows_tsf.dll";
}

} // namespace

int main(int argc, char** argv) {
    bool unregister = false;
    std::string dllPath;

    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i] == nullptr ? "" : argv[i];
        if (arg == "/u" || arg == "-u" || arg == "--unregister") {
            unregister = true;
            continue;
        }

        if (dllPath.empty()) {
            dllPath = arg;
        }
    }

    if (dllPath.empty()) {
        dllPath = defaultTsfDllPath();
    }
    dllPath = toAbsolutePath(dllPath);

    HMODULE module = LoadLibraryA(dllPath.c_str());
    if (module == nullptr) {
        std::cerr << "Failed to load TSF DLL: " << dllPath << "\n";
        return 1;
    }

    const char* exportName = unregister ? "DllUnregisterServer" : "DllRegisterServer";
    const FARPROC proc = GetProcAddress(module, exportName);
    if (proc == nullptr) {
        std::cerr << "Export not found: " << exportName << "\n";
        FreeLibrary(module);
        return 1;
    }

    auto fn = reinterpret_cast<DllRegisterServerFn>(proc);
    const HRESULT hr = fn();
    FreeLibrary(module);

    if (FAILED(hr)) {
        std::cerr << "Operation failed. HRESULT=0x" << std::hex << hr << std::dec << "\n";
        return 1;
    }

    std::cout << (unregister ? "TSF unregistered successfully." : "TSF registered successfully.") << "\n";
    return 0;
}

#endif // _WIN32
