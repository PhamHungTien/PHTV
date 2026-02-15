//
//  ConvertTool.cpp
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#include <algorithm>
#include <array>
#include <cwctype>
#include <map>
#include <unordered_map>
#include <utility>
#include <vector>

#include "ConvertTool.h"
#include "Engine.h"
#include "../PHTVConstants.h"

namespace {
constexpr Uint8 kDefaultCodeTable = static_cast<Uint8>(PHTVCodeTableUnicode);
constexpr Uint8 kMinCodeTable = static_cast<Uint8>(PHTVCodeTableUnicode);
constexpr Uint8 kMaxCodeTable = static_cast<Uint8>(PHTVCodeTableCP1258);
constexpr size_t kCodeTableCount = static_cast<size_t>(PHTVCodeTableCP1258) + 1;
constexpr ConvertToolOptions kDefaultConvertToolOptions = {
    false,           // dontAlertWhenCompleted
    false,           // toAllCaps
    false,           // toAllNonCaps
    false,           // toCapsFirstLetter
    false,           // toCapsEachWord
    false,           // removeMark
    kDefaultCodeTable,
    kDefaultCodeTable,
    static_cast<int>(EMPTY_HOTKEY)
};

struct ConvertToolOptionsSnapshot {
    bool toAllCaps;
    bool toAllNonCaps;
    bool toCapsFirstLetter;
    bool toCapsEachWord;
    bool removeMark;
    Uint8 fromCode;
    Uint8 toCode;
};

struct KeyCodeLookupEntry {
    Uint32 keyCode;
    size_t variantIndex;
};

typedef std::unordered_map<Uint16, KeyCodeLookupEntry> ReverseLookupTable;

static const std::array<Uint16, 3> kBreakCode = {'.', '?', '!'};

static Uint8 sanitizeCodeTable(const Uint8 codeTable) {
    if (codeTable < kMinCodeTable || codeTable > kMaxCodeTable) {
        return kDefaultCodeTable;
    }
    return codeTable;
}

static ConvertToolOptionsSnapshot snapshotConvertToolOptions() {
    ConvertToolOptionsSnapshot options = {
        gConvertToolOptions.toAllCaps,
        gConvertToolOptions.toAllNonCaps,
        gConvertToolOptions.toCapsFirstLetter,
        gConvertToolOptions.toCapsEachWord,
        gConvertToolOptions.removeMark,
        sanitizeCodeTable(gConvertToolOptions.fromCode),
        sanitizeCodeTable(gConvertToolOptions.toCode)
    };

    if (options.toAllCaps) {
        // All-caps wins over all other case transforms.
        options.toAllNonCaps = false;
        options.toCapsFirstLetter = false;
        options.toCapsEachWord = false;
    } else if (options.toAllNonCaps) {
        // All-lowercase conflicts with sentence/title caps.
        options.toCapsFirstLetter = false;
        options.toCapsEachWord = false;
    }

    return options;
}

static ReverseLookupTable buildReverseLookupForCodeTable(const Uint8 codeTable) {
    ReverseLookupTable reverseLookup;
    const std::map<Uint32, std::vector<Uint16>>& table = _codeTable[codeTable];
    for (std::map<Uint32, std::vector<Uint16>>::const_iterator tableIt = table.begin();
         tableIt != table.end();
         ++tableIt) {
        const Uint32 sourceKeyCode = tableIt->first;
        const std::vector<Uint16>& variants = tableIt->second;
        for (size_t idx = 0; idx < variants.size(); ++idx) {
            reverseLookup.insert(std::make_pair(variants[idx], KeyCodeLookupEntry{sourceKeyCode, idx}));
        }
    }
    return reverseLookup;
}

static const ReverseLookupTable& getReverseLookupTable(const Uint8 codeTable) {
    const Uint8 safeCodeTable = sanitizeCodeTable(codeTable);
    static const std::array<ReverseLookupTable, kCodeTableCount> reverseLookupTables = []() {
        std::array<ReverseLookupTable, kCodeTableCount> tables;
        for (Uint8 table = kMinCodeTable; table <= kMaxCodeTable; ++table) {
            tables[table] = buildReverseLookupForCodeTable(table);
        }
        return tables;
    }();
    return reverseLookupTables[safeCodeTable];
}

static bool findKeyCode(const Uint16 charCode,
                        const Uint8 codeTable,
                        Uint32& sourceKeyCode,
                        size_t& sourceVariantIndex) {
    const ReverseLookupTable& reverseLookup = getReverseLookupTable(codeTable);
    const ReverseLookupTable::const_iterator it = reverseLookup.find(charCode);
    if (it == reverseLookup.end()) {
        return false;
    }
    sourceKeyCode = it->second.keyCode;
    sourceVariantIndex = it->second.variantIndex;
    return true;
}

static Uint16 getUnicodeCompoundMarkIndex(const Uint16 mark) {
    for (size_t i = 0; i < 5; ++i) {
        if (mark == _unicodeCompoundMark[i]) {
            return static_cast<Uint16>((i + 1) << 13);
        }
    }
    return 0;
}

static bool getTargetCharacter(const ConvertToolOptionsSnapshot& options,
                               const Uint32 sourceKeyCode,
                               const size_t sourceVariantIndex,
                               const bool shouldUpperCase,
                               Uint16& targetCharacter) {
    const std::map<Uint32, std::vector<Uint16>>::const_iterator targetIt =
        _codeTable[options.toCode].find(sourceKeyCode);
    if (targetIt == _codeTable[options.toCode].end()) {
        return false;
    }

    const std::vector<Uint16>& targetVariants = targetIt->second;
    if (sourceVariantIndex >= targetVariants.size()) {
        return false;
    }

    size_t targetVariantIndex = sourceVariantIndex;
    const bool forceUpperCase = options.toAllCaps || shouldUpperCase;
    const bool forceLowerCase = options.toAllNonCaps || options.toCapsFirstLetter || options.toCapsEachWord;

    if (forceUpperCase && (targetVariantIndex % 2 != 0) && targetVariantIndex > 0) {
        targetVariantIndex--;
    } else if (forceLowerCase && (targetVariantIndex % 2 == 0) && (targetVariantIndex + 1) < targetVariants.size()) {
        targetVariantIndex++;
    }

    targetCharacter = targetVariants[targetVariantIndex];

    // Remove mark/tone and keep explicit all-caps/all-lower options.
    if (options.removeMark) {
        targetCharacter = keyCodeToCharacter(static_cast<Uint8>(sourceKeyCode));
        if (options.toAllCaps) {
            targetCharacter = static_cast<Uint16>(towupper(targetCharacter));
        } else if (options.toAllNonCaps) {
            targetCharacter = static_cast<Uint16>(towlower(targetCharacter));
        }
    }

    return true;
}

static void appendTargetByCode(const Uint8 codeTable,
                               const Uint16 targetCharacter,
                               std::vector<wchar_t>& output) {
    switch (codeTable) {
        case PHTVCodeTableUnicode:
        case PHTVCodeTableTCVN3:
            output.push_back(static_cast<wchar_t>(targetCharacter));
            return;

        case PHTVCodeTableVNIWindows:
        case PHTVCodeTableCP1258: {
            const Uint8 lowByte = static_cast<Uint8>(targetCharacter & 0xFF);
            const Uint8 highByte = static_cast<Uint8>((targetCharacter >> 8) & 0xFF);
            output.push_back(static_cast<wchar_t>(lowByte));
            if (highByte > 32) {
                output.push_back(static_cast<wchar_t>(highByte));
            }
            return;
        }

        case PHTVCodeTableUnicodeComposite:
            if ((targetCharacter >> 13) > 0) {
                output.push_back(static_cast<wchar_t>(targetCharacter & 0x1FFF));
                output.push_back(static_cast<wchar_t>(_unicodeCompoundMark[(targetCharacter >> 13) - 1]));
            } else {
                output.push_back(static_cast<wchar_t>(targetCharacter));
            }
            return;

        default:
            output.push_back(static_cast<wchar_t>(targetCharacter));
            return;
    }
}

static bool tryConvertCharacter(const Uint16 sourceCharacter,
                                const ConvertToolOptionsSnapshot& options,
                                const bool shouldUpperCase,
                                std::vector<wchar_t>& output) {
    Uint32 sourceKeyCode = 0;
    size_t sourceVariantIndex = 0;

    if (!findKeyCode(sourceCharacter, options.fromCode, sourceKeyCode, sourceVariantIndex)) {
        return false;
    }

    Uint16 targetCharacter = 0;
    if (!getTargetCharacter(options,
                            sourceKeyCode,
                            sourceVariantIndex,
                            shouldUpperCase,
                            targetCharacter)) {
        return false;
    }

    appendTargetByCode(options.toCode, targetCharacter, output);
    return true;
}

static bool isSentenceBreakCharacter(const Uint16 character) {
    return std::find(kBreakCode.begin(), kBreakCode.end(), character) != kBreakCode.end();
}
} // namespace

// Option values loaded from preferences.
ConvertToolOptions gConvertToolOptions = kDefaultConvertToolOptions;

ConvertToolOptions defaultConvertToolOptions() {
    return kDefaultConvertToolOptions;
}

void resetConvertToolOptions() {
    gConvertToolOptions = kDefaultConvertToolOptions;
}

void normalizeConvertToolOptions() {
    gConvertToolOptions.fromCode = sanitizeCodeTable(gConvertToolOptions.fromCode);
    gConvertToolOptions.toCode = sanitizeCodeTable(gConvertToolOptions.toCode);

    if (gConvertToolOptions.toAllCaps) {
        gConvertToolOptions.toAllNonCaps = false;
        gConvertToolOptions.toCapsFirstLetter = false;
        gConvertToolOptions.toCapsEachWord = false;
    } else if (gConvertToolOptions.toAllNonCaps) {
        gConvertToolOptions.toCapsFirstLetter = false;
        gConvertToolOptions.toCapsEachWord = false;
    }
}

std::string convertUtil(const std::string& sourceString) {
    const ConvertToolOptionsSnapshot options = snapshotConvertToolOptions();
    const std::wstring data = utf8ToWideString(sourceString);

    std::vector<wchar_t> converted;
    converted.reserve(data.size() + 4);

    bool hasBreak = false;
    bool shouldUpperCase = options.toCapsFirstLetter || options.toCapsEachWord;

    for (size_t i = 0; i < data.size(); ++i) {
        if (i + 1 < data.size()) {
            Uint16 compoundCharacter = static_cast<Uint16>(data[i]);
            size_t consumedExtraChars = 0;
            bool hasCompoundCandidate = false;

            switch (options.fromCode) {
                case PHTVCodeTableVNIWindows:
                case PHTVCodeTableCP1258:
                    compoundCharacter = static_cast<Uint16>(data[i]) |
                                        static_cast<Uint16>(static_cast<Uint16>(data[i + 1]) << 8);
                    consumedExtraChars = 1;
                    hasCompoundCandidate = true;
                    break;

                case PHTVCodeTableUnicodeComposite: {
                    const Uint16 mark = getUnicodeCompoundMarkIndex(static_cast<Uint16>(data[i + 1]));
                    if (mark > 0) {
                        compoundCharacter = static_cast<Uint16>(data[i]) | mark;
                        consumedExtraChars = 1;
                        hasCompoundCandidate = true;
                    }
                    break;
                }

                default:
                    break;
            }

            if (hasCompoundCandidate &&
                tryConvertCharacter(compoundCharacter, options, shouldUpperCase, converted)) {
                i += consumedExtraChars;
                shouldUpperCase = false;
                hasBreak = false;
                continue;
            }
        }

        const Uint16 singleCharacter = static_cast<Uint16>(data[i]);
        if (tryConvertCharacter(singleCharacter, options, shouldUpperCase, converted)) {
            shouldUpperCase = false;
            hasBreak = false;
            continue;
        }

        const bool forceUpperCase = options.toAllCaps || shouldUpperCase;
        const bool forceLowerCase = options.toAllNonCaps || options.toCapsFirstLetter || options.toCapsEachWord;

        if (forceUpperCase) {
            converted.push_back(static_cast<wchar_t>(towupper(data[i])));
        } else if (forceLowerCase) {
            converted.push_back(static_cast<wchar_t>(towlower(data[i])));
        } else {
            converted.push_back(data[i]);
        }

        if (singleCharacter == '\n' || (hasBreak && singleCharacter == ' ')) {
            if (options.toCapsFirstLetter || options.toCapsEachWord) {
                shouldUpperCase = true;
            }
        } else if (singleCharacter == ' ' && options.toCapsEachWord) {
            shouldUpperCase = true;
        } else if (isSentenceBreakCharacter(singleCharacter)) {
            hasBreak = true;
        } else {
            shouldUpperCase = false;
            hasBreak = false;
        }
    }

    const std::wstring result(converted.begin(), converted.end());
    return wideStringToUtf8(result);
}
