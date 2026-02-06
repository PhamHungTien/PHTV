#pragma once

#include <filesystem>

namespace phtv::windows_runtime {

struct DictionaryLoadStatus {
    bool englishLoaded = false;
    bool vietnameseLoaded = false;
    std::filesystem::path englishPath;
    std::filesystem::path vietnamesePath;
};

// Loads English/Vietnamese binary dictionaries for shared engine English restore.
// modulePath can be executable path (daemon) or DLL path (TSF).
DictionaryLoadStatus ensureDictionariesLoaded(const std::filesystem::path& modulePath = {});

} // namespace phtv::windows_runtime

