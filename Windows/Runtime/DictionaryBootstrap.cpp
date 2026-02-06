#ifdef _WIN32

#include "DictionaryBootstrap.h"

#include <algorithm>
#include <cstdlib>
#include <string>
#include <unordered_set>
#include <vector>
#include <windows.h>
#include "EnglishWordDetector.h"
#include "RuntimeConfig.h"

namespace {

std::filesystem::path executablePath() {
    std::vector<wchar_t> buffer(32768, L'\0');
    const DWORD length = GetModuleFileNameW(nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
    if (length == 0 || length >= buffer.size()) {
        return {};
    }

    return std::filesystem::path(std::wstring(buffer.data(), length));
}

std::filesystem::path resolveModulePath(const std::filesystem::path& modulePath) {
    if (!modulePath.empty()) {
        return modulePath;
    }
    return executablePath();
}

void appendUniquePath(std::vector<std::filesystem::path>& paths,
                      std::unordered_set<std::wstring>& seen,
                      const std::filesystem::path& candidate) {
    if (candidate.empty()) {
        return;
    }

    const std::filesystem::path normalized = candidate.lexically_normal();
    const std::wstring key = normalized.wstring();
    if (key.empty()) {
        return;
    }

    if (!seen.insert(key).second) {
        return;
    }

    paths.push_back(normalized);
}

std::vector<std::filesystem::path> buildDictionaryDirectoryCandidates(
    const std::filesystem::path& modulePath) {
    std::vector<std::filesystem::path> paths;
    std::unordered_set<std::wstring> seen;

    if (const char* dictDirEnv = std::getenv("PHTV_DICT_DIR")) {
        appendUniquePath(paths, seen, std::filesystem::path(dictDirEnv));
    }

    if (const char* runtimeDirEnv = std::getenv("PHTV_RUNTIME_DIR")) {
        const std::filesystem::path runtimeDir(runtimeDirEnv);
        appendUniquePath(paths, seen, runtimeDir);
        appendUniquePath(paths, seen, runtimeDir / "bin");
        appendUniquePath(paths, seen, runtimeDir / "bin" / "win-x64");
        appendUniquePath(paths, seen, runtimeDir / "bin" / "win-arm64");
    }

    const std::filesystem::path runtimeDir = phtv::windows_runtime::runtimeDirectory();
    appendUniquePath(paths, seen, runtimeDir);
    appendUniquePath(paths, seen, runtimeDir / "bin");
    appendUniquePath(paths, seen, runtimeDir / "bin" / "win-x64");
    appendUniquePath(paths, seen, runtimeDir / "bin" / "win-arm64");

    const std::filesystem::path resolvedModulePath = resolveModulePath(modulePath);
    if (!resolvedModulePath.empty()) {
        const std::filesystem::path moduleDir = resolvedModulePath.parent_path();
        appendUniquePath(paths, seen, moduleDir);
        appendUniquePath(paths, seen, moduleDir / "Dictionaries");
    }

    appendUniquePath(paths, seen, std::filesystem::current_path());
    appendUniquePath(paths, seen, std::filesystem::current_path() / "Dictionaries");

    std::filesystem::path cursor = !resolvedModulePath.empty()
        ? resolvedModulePath.parent_path()
        : std::filesystem::current_path();
    for (int depth = 0; depth < 8 && !cursor.empty(); ++depth) {
        appendUniquePath(paths, seen, cursor / "Resources" / "Dictionaries");
        appendUniquePath(paths, seen, cursor / "Shared" / "Resources" / "Dictionaries");
        appendUniquePath(paths, seen, cursor / "macOS" / "PHTV" / "Resources" / "Dictionaries");

        const std::filesystem::path parent = cursor.parent_path();
        if (parent.empty() || parent == cursor) {
            break;
        }
        cursor = parent;
    }

    return paths;
}

std::filesystem::path resolveDictionaryPath(const char* explicitEnvName,
                                            const char* fileName,
                                            const std::vector<std::filesystem::path>& candidates) {
    if (const char* explicitPath = std::getenv(explicitEnvName)) {
        const std::filesystem::path path(explicitPath);
        std::error_code ec;
        if (std::filesystem::exists(path, ec) && !ec) {
            return path;
        }
    }

    for (const auto& candidateDir : candidates) {
        const std::filesystem::path path = candidateDir / fileName;
        std::error_code ec;
        if (std::filesystem::exists(path, ec) && !ec) {
            return path;
        }
    }

    return {};
}

} // namespace

namespace phtv::windows_runtime {

DictionaryLoadStatus ensureDictionariesLoaded(const std::filesystem::path& modulePath) {
    DictionaryLoadStatus status;
    const auto candidates = buildDictionaryDirectoryCandidates(modulePath);

    const std::filesystem::path englishPath =
        resolveDictionaryPath("PHTV_EN_DICT_PATH", "en_dict.bin", candidates);
    if (!englishPath.empty() && initEnglishDictionary(englishPath.string())) {
        status.englishLoaded = true;
        status.englishPath = englishPath;
    }

    const std::filesystem::path vietnamesePath =
        resolveDictionaryPath("PHTV_VI_DICT_PATH", "vi_dict.bin", candidates);
    if (!vietnamesePath.empty() && initVietnameseDictionary(vietnamesePath.string())) {
        status.vietnameseLoaded = true;
        status.vietnamesePath = vietnamesePath;
    }

    return status;
}

} // namespace phtv::windows_runtime

#endif // _WIN32

