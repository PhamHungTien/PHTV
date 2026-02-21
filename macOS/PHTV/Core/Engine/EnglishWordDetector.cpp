//
//  EnglishWordDetector.cpp
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//
//  Ultra-fast English word detection using pre-built binary trie
//  O(1) load time + O(k) lookup where k = word length
//

#include "EnglishWordDetector.h"
#include <cstdint>
#include <cstring>
#include <cstdlib>
#ifdef _WIN32
#else
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#endif
#include <unordered_set>
#include <cstdio>

#include "../phtv_mac_keys.h"

using namespace std;

// ============================================================================
// Binary Trie Format (PHT3)
// - Header: "PHT3" (4) + node_count (4) + word_count (4) = 12 bytes
// - Each node: 26 x uint32 (child indices) + 1 byte (isEnd) = 105 bytes
// - 0xFFFFFFFF = no child
// ============================================================================

#pragma pack(push, 1)
struct BinaryTrieNode {
    uint32_t children[26];  // 0xFFFFFFFF = no child
    uint8_t isEnd;
};
#pragma pack(pop)

static_assert(sizeof(BinaryTrieNode) == 105, "BinaryTrieNode must be 105 bytes");

// ============================================================================
// Static Variables
// ============================================================================
static const BinaryTrieNode* engNodes = nullptr;
static const BinaryTrieNode* vieNodes = nullptr;
static uint32_t engNodeCount = 0;
static uint32_t vieNodeCount = 0;
static size_t engWordCount = 0;
static size_t vieWordCount = 0;
// Thread-safe initialization flags with volatile to prevent compiler optimization
static volatile bool engInit = false;
static volatile bool vieInit = false;

// Memory mapped file data
static void* engMmap = nullptr;
static void* vieMmap = nullptr;
static size_t engMmapSize = 0;
static size_t vieMmapSize = 0;

// Pre-computed lookup table: keycode -> letter index (0-25), 255 = invalid
alignas(64) static uint8_t kcToIdx[64];
static bool kcInit = false;

// Custom dictionary (Swift-backed runtime bridge)
static volatile int customEnglishWordCountCache = 0;
static volatile int customVietnameseWordCountCache = 0;
static std::unordered_set<std::string> customEnglishWordsFallback;
static std::unordered_set<std::string> customVietnameseWordsFallback;

extern "C" void phtvCustomDictionaryClear();
extern "C" void phtvCustomDictionaryLoadJSON(const char* jsonData, int length);
extern "C" int phtvCustomDictionaryEnglishCount();
extern "C" int phtvCustomDictionaryVietnameseCount();
extern "C" int phtvCustomDictionaryContainsEnglishWord(const char* wordCString);
extern "C" int phtvCustomDictionaryContainsVietnameseWord(const char* wordCString);
extern "C" int phtvDictionaryInitEnglish(const char* filePath);
extern "C" int phtvDictionaryInitVietnamese(const char* filePath);
extern "C" int phtvDictionaryIsEnglishInitialized();
extern "C" int phtvDictionaryEnglishWordCount();
extern "C" int phtvDictionaryVietnameseWordCount();
extern "C" int phtvDictionaryContainsEnglishIndices(const uint8_t* indices, int length);
extern "C" int phtvDictionaryContainsVietnameseIndices(const uint8_t* indices, int length);
extern "C" void phtvDictionaryClear();

static void initKcLookup() {
    if (kcInit) return;
    memset(kcToIdx, 255, sizeof(kcToIdx));
    kcToIdx[KEY_A] = 0;  kcToIdx[KEY_B] = 1;  kcToIdx[KEY_C] = 2;
    kcToIdx[KEY_D] = 3;  kcToIdx[KEY_E] = 4;  kcToIdx[KEY_F] = 5;
    kcToIdx[KEY_G] = 6;  kcToIdx[KEY_H] = 7;  kcToIdx[KEY_I] = 8;
    kcToIdx[KEY_J] = 9;  kcToIdx[KEY_K] = 10; kcToIdx[KEY_L] = 11;
    kcToIdx[KEY_M] = 12; kcToIdx[KEY_N] = 13; kcToIdx[KEY_O] = 14;
    kcToIdx[KEY_P] = 15; kcToIdx[KEY_Q] = 16; kcToIdx[KEY_R] = 17;
    kcToIdx[KEY_S] = 18; kcToIdx[KEY_T] = 19; kcToIdx[KEY_U] = 20;
    kcToIdx[KEY_V] = 21; kcToIdx[KEY_W] = 22; kcToIdx[KEY_X] = 23;
    kcToIdx[KEY_Y] = 24; kcToIdx[KEY_Z] = 25;
    kcInit = true;
}

static inline void lowercaseAsciiInPlace(std::string& word) {
    for (size_t i = 0; i < word.length(); i++) {
        if (word[i] >= 'A' && word[i] <= 'Z') {
            word[i] = static_cast<char>(word[i] - 'A' + 'a');
        }
    }
}

static void parseCustomDictionaryFallback(const char* jsonData, int length) {
    customEnglishWordsFallback.clear();
    customVietnameseWordsFallback.clear();

    if (!jsonData || length < 2) {
        return;
    }

    std::string json(jsonData, static_cast<size_t>(length));
    size_t pos = 0;
    while (pos < json.length()) {
        size_t wordKeyPos = json.find("\"word\":", pos);
        if (wordKeyPos == std::string::npos) break;

        size_t wordStart = json.find("\"", wordKeyPos + 7);
        if (wordStart == std::string::npos) break;
        wordStart++;
        size_t wordEnd = json.find("\"", wordStart);
        if (wordEnd == std::string::npos) break;
        std::string word = json.substr(wordStart, wordEnd - wordStart);

        size_t typeKeyPos = json.find("\"type\":", wordEnd);
        if (typeKeyPos == std::string::npos) {
            pos = wordEnd + 1;
            continue;
        }

        size_t typeStart = json.find("\"", typeKeyPos + 7);
        if (typeStart == std::string::npos) break;
        typeStart++;
        size_t typeEnd = json.find("\"", typeStart);
        if (typeEnd == std::string::npos) break;
        std::string type = json.substr(typeStart, typeEnd - typeStart);

        lowercaseAsciiInPlace(word);
        lowercaseAsciiInPlace(type);

        if (type == "en" || type == "english") {
            customEnglishWordsFallback.insert(word);
        } else if (type == "vi" || type == "vietnamese") {
            customVietnameseWordsFallback.insert(word);
        }

        pos = typeEnd + 1;
    }
}

extern "C" __attribute__((weak)) void phtvCustomDictionaryClear() {
    customEnglishWordsFallback.clear();
    customVietnameseWordsFallback.clear();
}

extern "C" __attribute__((weak)) void phtvCustomDictionaryLoadJSON(const char* jsonData, int length) {
    parseCustomDictionaryFallback(jsonData, length);
}

extern "C" __attribute__((weak)) int phtvCustomDictionaryEnglishCount() {
    return static_cast<int>(customEnglishWordsFallback.size());
}

extern "C" __attribute__((weak)) int phtvCustomDictionaryVietnameseCount() {
    return static_cast<int>(customVietnameseWordsFallback.size());
}

extern "C" __attribute__((weak)) int phtvCustomDictionaryContainsEnglishWord(const char* wordCString) {
    if (!wordCString) return 0;
    return customEnglishWordsFallback.count(wordCString) != 0 ? 1 : 0;
}

extern "C" __attribute__((weak)) int phtvCustomDictionaryContainsVietnameseWord(const char* wordCString) {
    if (!wordCString) return 0;
    return customVietnameseWordsFallback.count(wordCString) != 0 ? 1 : 0;
}

static inline bool customEnglishContainsWord(const char* wordCString) {
    if (!wordCString || customEnglishWordCountCache <= 0) {
        return false;
    }
    return phtvCustomDictionaryContainsEnglishWord(wordCString) != 0;
}

static inline bool customVietnameseContainsWord(const char* wordCString) {
    if (!wordCString || customVietnameseWordCountCache <= 0) {
        return false;
    }
    return phtvCustomDictionaryContainsVietnameseWord(wordCString) != 0;
}

static inline bool dictionaryEnglishInitialized() {
    return phtvDictionaryIsEnglishInitialized() != 0;
}

static inline bool dictionaryEnglishContainsIndices(const uint8_t* indices, int length) {
    if (!indices || length <= 0 || length > 30) {
        return false;
    }
    return phtvDictionaryContainsEnglishIndices(indices, length) != 0;
}

static inline bool dictionaryVietnameseContainsIndices(const uint8_t* indices, int length) {
    if (!indices || length <= 0 || length > 30) {
        return false;
    }
    return phtvDictionaryContainsVietnameseIndices(indices, length) != 0;
}

// ============================================================================
// Ultra-fast trie search on memory-mapped binary trie
// ============================================================================
static inline bool searchBinaryTrie(const BinaryTrieNode* __restrict nodes,
                                     const uint8_t* __restrict idx,
                                     int len) {
    uint32_t nodeIdx = 0;  // Start at root
    for (int i = 0; i < len; i++) {
        uint32_t child = nodes[nodeIdx].children[idx[i]];
        if (child == 0xFFFFFFFF) return false;
        nodeIdx = child;
    }
    return nodes[nodeIdx].isEnd;
}

// ============================================================================
// Telex conflict detection (helps decide when to relax English matching)
// ============================================================================
static inline bool hasTelexConflict(const char* word, int len) {
    if (len < 2) return false;
    for (int i = 0; i < len - 1; i++) {
        char c1 = word[i];
        char c2 = word[i + 1];

        // Double vowels: aa -> â, ee -> ê, oo -> ô
        if ((c1 == 'a' && c2 == 'a') || (c1 == 'e' && c2 == 'e') || (c1 == 'o' && c2 == 'o')) {
            return true;
        }
        // Horn marks: aw -> ă, ow -> ơ, uw -> ư
        if ((c1 == 'a' && c2 == 'w') || (c1 == 'o' && c2 == 'w') || (c1 == 'u' && c2 == 'w')) {
            return true;
        }
        // dd -> đ
        if (c1 == 'd' && c2 == 'd') {
            return true;
        }
        // Vowel + tone mark: s, f, r, x, j
        if ((c1 == 'a' || c1 == 'e' || c1 == 'i' || c1 == 'o' || c1 == 'u') &&
            (c2 == 's' || c2 == 'f' || c2 == 'r' || c2 == 'x' || c2 == 'j')) {
            return true;
        }
    }
    return false;
}

static inline bool endsWithSuffix(const uint8_t* idx, int len, const char* suffix, int suffixLen) {
    if (len < suffixLen) return false;
    int start = len - suffixLen;
    for (int i = 0; i < suffixLen; i++) {
        if (idx[start + i] != (uint8_t)(suffix[i] - 'a')) return false;
    }
    return true;
}

static inline bool startsWithNonVietnameseCluster(const uint8_t* idx, int len) {
    if (len <= 0) return false;
    char first = (char)('a' + idx[0]);
    char second = (len > 1) ? (char)('a' + idx[1]) : '\0';
    char third = (len > 2) ? (char)('a' + idx[2]) : '\0';

    // Letters not used in Vietnamese spelling
    if (first == 'f' || first == 'j' || first == 'w' || first == 'z') return true;

    // Common English clusters that don't exist in Vietnamese
    if (second) {
        if ((first == 'b' && (second == 'l' || second == 'r')) ||
            (first == 'c' && (second == 'l' || second == 'r')) ||
            (first == 'd' && second == 'r') ||
            (first == 'f' && (second == 'l' || second == 'r')) ||
            (first == 'g' && (second == 'l' || second == 'r')) ||
            (first == 'p' && (second == 'l' || second == 'r')) ||
            (first == 's' && (second == 'c' || second == 'k' || second == 'l' || second == 'm' ||
                              second == 'n' || second == 'p' || second == 't' || second == 'w' ||
                              second == 'q')) ||
            (first == 't' && second == 'w') ||
            (first == 'w' && second == 'r')) {
            return true;
        }
    }

    // 3-letter clusters
    if (third) {
        if ((first == 's' && second == 'h' && third == 'r') ||
            (first == 's' && second == 't' && third == 'r') ||
            (first == 's' && second == 'p' && third == 'r') ||
            (first == 's' && second == 'c' && third == 'r')) {
            return true;
        }
    }

    return false;
}

// ============================================================================
// Load binary trie using mmap (POSIX) or buffered file read (Windows)
// ============================================================================
static bool loadBinaryTrie(const char* path,
                           void*& mmapPtr, size_t& mmapSize,
                           const BinaryTrieNode*& nodes,
                           uint32_t& nodeCount, size_t& wordCount) {
#ifdef _WIN32
    FILE* fp = fopen(path, "rb");
    if (!fp) return false;

    if (fseek(fp, 0, SEEK_END) != 0) {
        fclose(fp);
        return false;
    }

    long fileSizeLong = ftell(fp);
    if (fileSizeLong < 12) {
        fclose(fp);
        return false;
    }

    size_t fileSize = static_cast<size_t>(fileSizeLong);
    if (fseek(fp, 0, SEEK_SET) != 0) {
        fclose(fp);
        return false;
    }

    uint8_t* mapped = static_cast<uint8_t*>(malloc(fileSize));
    if (!mapped) {
        fclose(fp);
        return false;
    }

    size_t bytesRead = fread(mapped, 1, fileSize, fp);
    fclose(fp);
    if (bytesRead != fileSize) {
        free(mapped);
        return false;
    }

    const uint8_t* data = mapped;
    if (memcmp(data, "PHT3", 4) != 0) {
        free(mapped);
        return false;
    }

    uint32_t nCount = *(const uint32_t*)(data + 4);
    uint32_t wCount = *(const uint32_t*)(data + 8);
    size_t expectedSize = 12 + (size_t)nCount * sizeof(BinaryTrieNode);
    if (fileSize < expectedSize) {
        free(mapped);
        return false;
    }

    mmapPtr = mapped;
    mmapSize = fileSize;
    nodes = (const BinaryTrieNode*)(data + 12);
    nodeCount = nCount;
    wordCount = wCount;
    return true;
#else
    int fd = open(path, O_RDONLY);
    if (fd < 0) return false;

    struct stat st;
    if (fstat(fd, &st) < 0) {
        close(fd);
        return false;
    }

    size_t fileSize = st.st_size;
    if (fileSize < 12) {  // Minimum: header only
        close(fd);
        return false;
    }

    // Memory map the file
    void* mapped = mmap(nullptr, fileSize, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);

    if (mapped == MAP_FAILED) return false;

    // Verify header (support both PHT2 and PHT3)
    const uint8_t* data = (const uint8_t*)mapped;
    if (memcmp(data, "PHT3", 4) != 0) {
        munmap(mapped, fileSize);
        return false;
    }

    // Read header
    uint32_t nCount = *(const uint32_t*)(data + 4);
    uint32_t wCount = *(const uint32_t*)(data + 8);

    // Verify file size
    size_t expectedSize = 12 + (size_t)nCount * sizeof(BinaryTrieNode);
    if (fileSize < expectedSize) {
        munmap(mapped, fileSize);
        return false;
    }

    // Set output
    mmapPtr = mapped;
    mmapSize = fileSize;
    nodes = (const BinaryTrieNode*)(data + 12);
    nodeCount = nCount;
    wordCount = wCount;

    return true;
#endif
}

// ============================================================================
// Weak fallback bridge for standalone C++ targets (no Swift linkage)
// ============================================================================
static bool fallbackInitEnglishDictionary(const string& filePath) {
    if (engInit) return true;
    initKcLookup();

    string binPath = filePath;
    size_t dotPos = binPath.rfind('.');
    if (dotPos != string::npos) {
        binPath = binPath.substr(0, dotPos) + ".bin";
    }

    if (loadBinaryTrie(binPath.c_str(), engMmap, engMmapSize,
                       engNodes, engNodeCount, engWordCount)) {
        engInit = true;
        return true;
    }

    if (dotPos != string::npos) {
        string baseName = filePath.substr(0, dotPos);
        if (baseName.length() >= 6 && baseName.substr(baseName.length() - 6) == "_words") {
            binPath = baseName.substr(0, baseName.length() - 6) + "_dict.bin";
            if (loadBinaryTrie(binPath.c_str(), engMmap, engMmapSize,
                               engNodes, engNodeCount, engWordCount)) {
                engInit = true;
                return true;
            }
        }
    }

    return false;
}

static bool fallbackInitVietnameseDictionary(const string& filePath) {
    if (vieInit) return true;
    initKcLookup();

    string binPath = filePath;
    size_t dotPos = binPath.rfind('.');
    if (dotPos != string::npos) {
        binPath = binPath.substr(0, dotPos) + ".bin";
    }

    if (loadBinaryTrie(binPath.c_str(), vieMmap, vieMmapSize,
                       vieNodes, vieNodeCount, vieWordCount)) {
        vieInit = true;
        return true;
    }

    if (dotPos != string::npos) {
        string baseName = filePath.substr(0, dotPos);
        if (baseName.length() >= 6 && baseName.substr(baseName.length() - 6) == "_words") {
            binPath = baseName.substr(0, baseName.length() - 6) + "_dict.bin";
            if (loadBinaryTrie(binPath.c_str(), vieMmap, vieMmapSize,
                               vieNodes, vieNodeCount, vieWordCount)) {
                vieInit = true;
                return true;
            }
        }
    }

    return false;
}

static void fallbackClearDictionaries() {
    if (engMmap) {
#ifdef _WIN32
        free(engMmap);
#else
        munmap(engMmap, engMmapSize);
#endif
        engMmap = nullptr;
        engNodes = nullptr;
    }
    if (vieMmap) {
#ifdef _WIN32
        free(vieMmap);
#else
        munmap(vieMmap, vieMmapSize);
#endif
        vieMmap = nullptr;
        vieNodes = nullptr;
    }

    engInit = false;
    vieInit = false;
    engWordCount = 0;
    vieWordCount = 0;
    engNodeCount = 0;
    vieNodeCount = 0;
}

extern "C" __attribute__((weak)) int phtvDictionaryInitEnglish(const char* filePath) {
    if (!filePath) return 0;
    return fallbackInitEnglishDictionary(string(filePath)) ? 1 : 0;
}

extern "C" __attribute__((weak)) int phtvDictionaryInitVietnamese(const char* filePath) {
    if (!filePath) return 0;
    return fallbackInitVietnameseDictionary(string(filePath)) ? 1 : 0;
}

extern "C" __attribute__((weak)) int phtvDictionaryIsEnglishInitialized() {
    return engInit ? 1 : 0;
}

extern "C" __attribute__((weak)) int phtvDictionaryEnglishWordCount() {
    return static_cast<int>(engWordCount);
}

extern "C" __attribute__((weak)) int phtvDictionaryVietnameseWordCount() {
    return static_cast<int>(vieWordCount);
}

extern "C" __attribute__((weak)) int phtvDictionaryContainsEnglishIndices(const uint8_t* indices, int length) {
    if (!engInit || !engNodes || !indices || length <= 0 || length > 30) {
        return 0;
    }
    return searchBinaryTrie(engNodes, indices, length) ? 1 : 0;
}

extern "C" __attribute__((weak)) int phtvDictionaryContainsVietnameseIndices(const uint8_t* indices, int length) {
    if (!vieInit || !vieNodes || !indices || length <= 0 || length > 30) {
        return 0;
    }
    return searchBinaryTrie(vieNodes, indices, length) ? 1 : 0;
}

extern "C" __attribute__((weak)) void phtvDictionaryClear() {
    fallbackClearDictionaries();
}

// ============================================================================
// Public API
// ============================================================================
bool initEnglishDictionary(const string& filePath) {
    if (dictionaryEnglishInitialized()) return true;
    initKcLookup();
    return phtvDictionaryInitEnglish(filePath.c_str()) != 0;
}

bool initVietnameseDictionary(const string& filePath) {
    initKcLookup();
    return phtvDictionaryInitVietnamese(filePath.c_str()) != 0;
}

bool isEnglishDictionaryInitialized() { return dictionaryEnglishInitialized(); }
size_t getEnglishDictionarySize() {
    const int count = phtvDictionaryEnglishWordCount();
    return count > 0 ? static_cast<size_t>(count) : 0;
}
size_t getVietnameseDictionarySize() {
    const int count = phtvDictionaryVietnameseWordCount();
    return count > 0 ? static_cast<size_t>(count) : 0;
}

bool isEnglishWord(const string& word) {
    if (!dictionaryEnglishInitialized() || word.empty()) return false;
    uint8_t idx[32];
    int len = 0;
    for (size_t i = 0; i < word.length() && len < 30; i++) {
        char c = word[i];
        if (c >= 'a' && c <= 'z') idx[len++] = c - 'a';
        else if (c >= 'A' && c <= 'Z') idx[len++] = c - 'A';
        else return false;
    }
    return dictionaryEnglishContainsIndices(idx, len);
}

bool isEnglishWordFromKeyStates(const Uint32* keyStates, int stateIndex) {
    if (stateIndex <= 0 || stateIndex > 30) return false;
    if (!dictionaryEnglishInitialized() && customEnglishWordCountCache == 0) return false;

    initKcLookup();

    uint8_t idx[32];
    char wordBuf[32];
    for (int i = 0; i < stateIndex; i++) {
        uint8_t id = kcToIdx[keyStates[i] & 0x3F];
        if (id >= 26) return false;
        idx[i] = id;
        wordBuf[i] = 'a' + id;
    }
    wordBuf[stateIndex] = '\0';

    if (customEnglishContainsWord(wordBuf)) {
        return true;
    }

    return dictionaryEnglishContainsIndices(idx, stateIndex);
}

bool isVietnameseWordFromKeyStates(const Uint32* keyStates, int stateIndex) {
    if (stateIndex <= 0 || stateIndex > 30) return false;
    if (phtvDictionaryVietnameseWordCount() <= 0 && customVietnameseWordCountCache == 0) return false;

    initKcLookup();

    uint8_t idx[32];
    char wordBuf[32];
    for (int i = 0; i < stateIndex; i++) {
        uint8_t id = kcToIdx[keyStates[i] & 0x3F];
        if (id >= 26) return false;
        idx[i] = id;
        wordBuf[i] = 'a' + id;
    }
    wordBuf[stateIndex] = '\0';

    if (customVietnameseContainsWord(wordBuf)) {
        return true;
    }

    return dictionaryVietnameseContainsIndices(idx, stateIndex);
}

string keyStatesToString(const Uint32* keyCodes, int count) {
    initKcLookup();
    string result;
    result.reserve(count);
    for (int i = 0; i < count; i++) {
        uint8_t kc = keyCodes[i] & 0x3F;
        if (kc < 64 && kcToIdx[kc] < 26) {
            result += ('a' + kcToIdx[kc]);
        }
    }
    return result;
}

// ============================================================================
// ULTRA-FAST: Check if should restore to English
// Zero allocation, direct memory access
// Logic: Vietnamese-first - only restore if NOT Vietnamese AND IS English
// Priority: Custom Vietnamese > Custom English > Built-in Vietnamese > Built-in English
// ============================================================================
bool checkIfEnglishWord(const Uint32* keyStates, int stateIndex) {
    // Quick validation
    if (!dictionaryEnglishInitialized()) {
        #ifdef DEBUG
        fprintf(stderr, "[AutoEnglish] FAILED: Dictionary not initialized\n"); fflush(stderr);
        #endif
        return false;
    }
    if (stateIndex < 2) {
        #ifdef DEBUG
        fprintf(stderr, "[AutoEnglish] FAILED: Word too short (length=%d)\n", stateIndex); fflush(stderr);
        #endif
        return false;
    }
    if (stateIndex > 30) return false;

    // Initialize keycode lookup table if not already done
    initKcLookup();

    // Convert keycodes to indices and build word string
    uint8_t idx[32];
    char wordBuf[32];
    for (int i = 0; i < stateIndex; i++) {
        uint8_t id = kcToIdx[keyStates[i] & 0x3F];
        if (id >= 26) {
            #ifdef DEBUG
            fprintf(stderr, "[AutoEnglish] FAILED: Contains non-letter character at position %d\n", i); fflush(stderr);
            #endif
            return false;
        }
        idx[i] = id;
        wordBuf[i] = 'a' + id;
    }
    wordBuf[stateIndex] = '\0';
    std::string word(wordBuf);

    #ifdef DEBUG
    fprintf(stderr, "[AutoEnglish] Checking word: '%s'\n", word.c_str()); fflush(stderr);
    #endif

    // PRIORITY 1: Check custom Vietnamese - if user marked as Vietnamese, never restore
    if (customVietnameseContainsWord(word.c_str())) {
        #ifdef DEBUG
        fprintf(stderr, "[AutoEnglish] SKIP: '%s' is in custom Vietnamese dictionary\n", word.c_str()); fflush(stderr);
        #endif
        return false; // User explicitly marked as Vietnamese - do NOT restore
    }

    // PRIORITY 2: Check custom English - if user marked as English, always restore
    if (customEnglishContainsWord(word.c_str())) {
        #ifdef DEBUG
        fprintf(stderr, "[AutoEnglish] RESTORE: '%s' is in custom English dictionary\n", word.c_str()); fflush(stderr);
        #endif
        return true; // User explicitly marked as English - restore
    }

    // PRIORITY 3: Check built-in Vietnamese dictionary FIRST
    // This prevents Telex patterns from being incorrectly restored as English
    // Examples: "cos" → "có", "max" → "mã", etc.
    if (dictionaryVietnameseContainsIndices(idx, stateIndex)) {
        #ifdef DEBUG
        fprintf(stderr, "[AutoEnglish] SKIP: '%s' found in Vietnamese dictionary\n", word.c_str()); fflush(stderr);
        #endif
        return false; // It's a Vietnamese word - do NOT restore
    }

    // CRITICAL FIX: Check Vietnamese dictionary WITHOUT the last key if it's a Telex tone mark
    // Problem: When typing "d > i > d" (to make "đi"), KeyStates = ['d','i','d'] (3 keys)
    //          but Vietnamese dictionary only has "di" (2 letters), not "did" (3 letters)
    // Solution: If last key is a tone mark (d,s,f,r,x,j,w,a,o,e,[,]), also check without it
    // Examples: "did" → check "di" (đi), "dod" → check "do" (đo), "dad" → check "da" (đa)
    //
    // IMPROVED LOGIC (Fix for Issue #57 vs "fix" conflict):
    // Only apply tone mark check if word WITHOUT tone mark starts with Vietnamese consonant OR vowel
    // Vietnamese consonants: b,c,ch,d,đ,g,gh,gi,h,k,kh,l,m,n,ng,ngh,nh,p,ph,qu,r,s,t,th,tr,v,x
    // Vietnamese vowels: a,e,i,o,u,y (standalone vowels can have tone marks too)
    // Examples:
    //   "did" (d+i+d) → "di" starts with 'd' (Vietnamese) → check tone mark → block "did"
    //   "fix" (f+i+x) → "fi" starts with 'f' (NOT Vietnamese) → skip tone mark → allow "fix"
    //   "aws" (a+w+s) → "aw" starts with 'a' (Vietnamese vowel) → check tone mark → block "aws" (ắ)
    //   "eee" (e+e+e) → "ee" starts with 'e' (Vietnamese vowel) → check tone mark → block "eee" (ê + e)
    if (stateIndex >= 2) {
        uint8_t lastKey = keyStates[stateIndex - 1] & 0x3F;
        // Telex tone marks: s(sắc), f(huyền), r(hỏi), x(ngã), j(nặng), w(horn), a/o/e(^), [](ơ/ư)
        // Special-case 'd' only when the word starts with 'd' (e.g., "did" -> "đi").
        // This avoids the "add" -> "ađ" regression while restoring Vietnamese priority for d...d.
        bool isToneMark = (lastKey == KEY_S || lastKey == KEY_F ||
                          lastKey == KEY_R || lastKey == KEY_X || lastKey == KEY_J ||
                          lastKey == KEY_W || lastKey == KEY_A || lastKey == KEY_O ||
                          lastKey == KEY_E || lastKey == KEY_LEFT_BRACKET || lastKey == KEY_RIGHT_BRACKET ||
                          (lastKey == KEY_D && (keyStates[0] & 0x3F) == KEY_D));

        if (isToneMark) {
            // Check if word without tone mark starts with Vietnamese consonant or vowel
            uint8_t firstKey = keyStates[0] & 0x3F;
            uint8_t secondKey = (stateIndex >= 3) ? (keyStates[1] & 0x3F) : 0xFF;

            // EARLY EXIT: Check for non-Vietnamese consonant clusters at start
            // These patterns don't exist in Vietnamese, so skip tone mark logic entirely
            // Examples: bl, br, cl, cr, dr, fl, fr, gl, gr, pl, pr, sc, sk, sl, sm, sn, sp, st, sw, tw, wr
            // Fix for Issue #121: "clear" (cl) should be restored in terminal
            bool isNonVietnameseCluster = false;
            if (stateIndex >= 3) {
                // Common English clusters that don't exist in Vietnamese
                if ((firstKey == KEY_B && secondKey == KEY_L) ||  // bl (black, blue, clear)
                    (firstKey == KEY_B && secondKey == KEY_R) ||  // br (break, brown)
                    (firstKey == KEY_C && secondKey == KEY_L) ||  // cl (clear, close, class)
                    (firstKey == KEY_C && secondKey == KEY_R) ||  // cr (create, cross)
                    (firstKey == KEY_D && secondKey == KEY_R) ||  // dr (drop, drive)
                    (firstKey == KEY_F && secondKey == KEY_L) ||  // fl (flow, flag)
                    (firstKey == KEY_F && secondKey == KEY_R) ||  // fr (from, free)
                    (firstKey == KEY_G && secondKey == KEY_L) ||  // gl (global, glass)
                    (firstKey == KEY_G && secondKey == KEY_R) ||  // gr (great, green)
                    (firstKey == KEY_P && secondKey == KEY_L) ||  // pl (play, place)
                    (firstKey == KEY_P && secondKey == KEY_R) ||  // pr (print, process)
                    (firstKey == KEY_S && secondKey == KEY_C) ||  // sc (scan, scope)
                    (firstKey == KEY_S && secondKey == KEY_K) ||  // sk (skip, skill)
                    (firstKey == KEY_S && secondKey == KEY_L) ||  // sl (slow, sleep)
                    (firstKey == KEY_S && secondKey == KEY_M) ||  // sm (small, smart)
                    (firstKey == KEY_S && secondKey == KEY_N) ||  // sn (snap, snow)
                    (firstKey == KEY_S && secondKey == KEY_P) ||  // sp (space, speed)
                    (firstKey == KEY_S && secondKey == KEY_T) ||  // st (start, stop)
                    (firstKey == KEY_S && secondKey == KEY_W) ||  // sw (switch, swap)
                    (firstKey == KEY_T && secondKey == KEY_W) ||  // tw (two, twist)
                    (firstKey == KEY_W && secondKey == KEY_R)) {  // wr (write, wrong)
                    isNonVietnameseCluster = true;
                }

                // IMPROVED: Check triple consonant "thr" (three, throw, etc.)
                // This was missing and is common in English
                uint8_t thirdKey = (stateIndex >= 4) ? (keyStates[2] & 0x3F) : 0xFF;
                if (firstKey == KEY_T && secondKey == KEY_H && thirdKey == KEY_R) {  // thr
                    isNonVietnameseCluster = true;
                }
            }

            // If word starts with non-Vietnamese cluster, skip tone mark logic
            // and go directly to English dictionary check
            if (isNonVietnameseCluster) {
                #ifdef DEBUG
                fprintf(stderr, "[AutoEnglish] SKIP TONE CHECK: '%s' starts with non-Vietnamese cluster\n", wordBuf); fflush(stderr);
                #endif
                // Fall through to English dictionary check at line 418+
            } else {
                // Vietnamese consonants (single): b,c,d,g,h,k,l,m,n,p,r,s,t,v,x
                // Vietnamese consonants (double): ch,gh,gi,kh,ng,nh,ph,qu,th,tr,ngh
                bool isVietnameseConsonant = false;

                // Check single consonants (not 'f', 'j', 'w', 'z', 'q' alone)
                if (firstKey == KEY_B || firstKey == KEY_C || firstKey == KEY_D ||
                    firstKey == KEY_G || firstKey == KEY_H || firstKey == KEY_K ||
                    firstKey == KEY_L || firstKey == KEY_M || firstKey == KEY_N ||
                    firstKey == KEY_P || firstKey == KEY_R || firstKey == KEY_S ||
                    firstKey == KEY_T || firstKey == KEY_V || firstKey == KEY_X) {
                    isVietnameseConsonant = true;
                }

                // Check double consonants
                if (stateIndex >= 3) {
                    if ((firstKey == KEY_C && secondKey == KEY_H) ||  // ch
                        (firstKey == KEY_G && secondKey == KEY_H) ||  // gh
                        (firstKey == KEY_G && secondKey == KEY_I) ||  // gi
                        (firstKey == KEY_K && secondKey == KEY_H) ||  // kh
                        (firstKey == KEY_N && secondKey == KEY_G) ||  // ng
                        (firstKey == KEY_N && secondKey == KEY_H) ||  // nh
                        (firstKey == KEY_P && secondKey == KEY_H) ||  // ph
                        (firstKey == KEY_Q && secondKey == KEY_U) ||  // qu
                        (firstKey == KEY_T && secondKey == KEY_H) ||  // th
                        (firstKey == KEY_T && secondKey == KEY_R)) {  // tr
                        isVietnameseConsonant = true;
                    }

                    // IMPROVED: Check triple consonant "ngh" (nghe, anh, etc.)
                    // This was missing and caused "ngh*" words to be misidentified
                    uint8_t thirdKey = (stateIndex >= 4) ? (keyStates[2] & 0x3F) : 0xFF;
                    if (firstKey == KEY_N && secondKey == KEY_G && thirdKey == KEY_H) {  // ngh
                        isVietnameseConsonant = true;
                    }
                }

                // Check Vietnamese vowels: a, e, i, o, u, y, w
                // Vowels can also start Vietnamese words and have tone marks applied
                // Examples: "ắ" (aws), "ê" (ee), "ô" (oo), "ư" (uw), etc.
                // KEY_W is included because standalone W produces "ư" (Vietnamese vowel)
                // Without this, "wf" (standalone W + huyền = "ừ") would not be recognized
                bool isVietnameseVowel = (firstKey == KEY_A || firstKey == KEY_E ||
                                          firstKey == KEY_I || firstKey == KEY_O ||
                                          firstKey == KEY_U || firstKey == KEY_Y ||
                                          firstKey == KEY_W);

                // Check Vietnamese dictionary without tone mark if starts with Vietnamese consonant OR vowel
                if ((isVietnameseConsonant || isVietnameseVowel) && dictionaryVietnameseContainsIndices(idx, stateIndex - 1)) {
                    // EXCEPTION: Allow English only if the word is clearly non-Vietnamese by its start cluster.
                    // This keeps English like "footer" while preserving Vietnamese priority for words like "theme" -> "thêm".
                    if (stateIndex >= 4 && dictionaryEnglishContainsIndices(idx, stateIndex)) {
                        if (startsWithNonVietnameseCluster(idx, stateIndex)) {
                            #ifdef DEBUG
                            fprintf(stderr, "[AutoEnglish] ALLOW: '%s' starts with non-Vietnamese cluster\n", wordBuf); fflush(stderr);
                            #endif
                            return true;
                        }
                    }

                    #ifdef DEBUG
                    // Build word without tone mark for debug message
                    char wordWithoutTone[32];
                    for (int i = 0; i < stateIndex - 1; i++) {
                        wordWithoutTone[i] = 'a' + idx[i];
                    }
                    wordWithoutTone[stateIndex - 1] = '\0';
                    fprintf(stderr, "[AutoEnglish] SKIP: '%s' (without tone '%c') found in Vietnamese dictionary and starts with Vietnamese %s\n",
                           wordWithoutTone, 'a' + idx[stateIndex - 1],
                           isVietnameseConsonant ? "consonant" : "vowel"); fflush(stderr);
                    #endif
                    return false; // It's a Vietnamese word with tone mark - do NOT restore
                }
            }
        }
    }

    // PRIORITY 4: Check built-in English dictionary (only if NOT in Vietnamese)
    if (!dictionaryEnglishInitialized()) {
        #ifdef DEBUG
        fprintf(stderr, "[AutoEnglish] SKIP: '%s' - English dictionary not loaded\n", word.c_str()); fflush(stderr);
        #endif
        return false;
    }

    bool isEnglish = dictionaryEnglishContainsIndices(idx, stateIndex);

    // IMPROVED FIX: Check if word has tone mark ở giữa and not in dictionary
    // Issue #57: "livestream" with 'e+s' creating 'é' was not being restored
    // Solution: If word is not found but contains tone mark in middle, try removing it
    if (!isEnglish && stateIndex >= 3) {
        // Check for tone marks in the middle of the word (not at the end)
        bool hasToneMarkInMiddle = false;
        uint8_t tonelessIdx[32];
        int tonelessLen = 0;

        for (int i = 0; i < stateIndex - 1; i++) {  // Check all except last char
            uint8_t id = idx[i];
            uint8_t nextId = idx[i + 1];

            // Check if next char is a tone mark
            bool isNextToneMark = (nextId == kcToIdx[KEY_S] || nextId == kcToIdx[KEY_F] ||
                                  nextId == kcToIdx[KEY_R] || nextId == kcToIdx[KEY_X] ||
                                  nextId == kcToIdx[KEY_J] || nextId == kcToIdx[KEY_W]);

            if (isNextToneMark && (id == kcToIdx[KEY_A] || id == kcToIdx[KEY_E] ||
                                   id == kcToIdx[KEY_I] || id == kcToIdx[KEY_O] ||
                                   id == kcToIdx[KEY_U])) {
                hasToneMarkInMiddle = true;
                break;
            }
        }

        // If tone mark found in middle, try removing it and check again
        if (hasToneMarkInMiddle) {
            tonelessLen = 0;
            for (int i = 0; i < stateIndex; i++) {
                uint8_t id = idx[i];
                uint8_t nextId = (i + 1 < stateIndex) ? idx[i + 1] : 0xFF;

                // Skip tone mark if it's after a vowel
                bool isNextToneMark = (nextId == kcToIdx[KEY_S] || nextId == kcToIdx[KEY_F] ||
                                      nextId == kcToIdx[KEY_R] || nextId == kcToIdx[KEY_X] ||
                                      nextId == kcToIdx[KEY_J] || nextId == kcToIdx[KEY_W]);

                bool isVowel = (id == kcToIdx[KEY_A] || id == kcToIdx[KEY_E] ||
                               id == kcToIdx[KEY_I] || id == kcToIdx[KEY_O] ||
                               id == kcToIdx[KEY_U]);

                tonelessIdx[tonelessLen++] = id;

                if (isVowel && isNextToneMark) {
                    i++;  // Skip the tone mark
                }
            }

            // Try the toneless version
            if (tonelessLen >= 2 && tonelessLen < 32) {
                if (dictionaryEnglishContainsIndices(tonelessIdx, tonelessLen)) {
                    // Check Vietnamese without tone mark too
                    if (!dictionaryVietnameseContainsIndices(tonelessIdx, tonelessLen)) {
                        #ifdef DEBUG
                        char tonelessWord[32];
                        for (int i = 0; i < tonelessLen; i++) tonelessWord[i] = 'a' + tonelessIdx[i];
                        tonelessWord[tonelessLen] = '\0';
                        fprintf(stderr, "[AutoEnglish] RESTORE: '%s' restored as '%s' (tone mark removed)\n",
                               word.c_str(), tonelessWord); fflush(stderr);
                        #endif
                        return true;
                    }
                }
            }
        }
    }

    #ifdef DEBUG
    if (isEnglish) {
        fprintf(stderr, "[AutoEnglish] RESTORE: '%s' found in English dictionary\n", word.c_str()); fflush(stderr);
    } else {
        fprintf(stderr, "[AutoEnglish] SKIP: '%s' not found in English dictionary\n", word.c_str()); fflush(stderr);
    }
    #endif

    // Fallback: allow common suffixes if the base word is English
    // This fixes cases like "footer" (foot + er), "zoomed" (zoom + ed) when
    // full word is missing in dictionary but still clearly English.
    if (!isEnglish && hasTelexConflict(wordBuf, stateIndex)) {
        auto tryDerivedReplacement = [&](const char* suffixFrom,
                                         int suffixFromLen,
                                         const char* suffixTo,
                                         int suffixToLen) -> bool {
            if (stateIndex <= suffixFromLen + 1) return false;
            if (!endsWithSuffix(idx, stateIndex, suffixFrom, suffixFromLen)) return false;

            int stemLen = stateIndex - suffixFromLen;
            int derivedLen = stemLen + suffixToLen;
            if (derivedLen < 2 || derivedLen >= 32) return false;

            uint8_t derivedIdx[32];
            for (int i = 0; i < stemLen; i++) {
                derivedIdx[i] = idx[i];
            }
            for (int i = 0; i < suffixToLen; i++) {
                derivedIdx[stemLen + i] = static_cast<uint8_t>(suffixTo[i] - 'a');
            }

            if (!dictionaryEnglishContainsIndices(derivedIdx, derivedLen)) return false;

            bool derivedNonVietnameseStart = startsWithNonVietnameseCluster(derivedIdx, derivedLen);
            if (!derivedNonVietnameseStart && dictionaryVietnameseContainsIndices(derivedIdx, derivedLen)) {
                return false;
            }

            #ifdef DEBUG
            char derivedWord[32];
            for (int i = 0; i < derivedLen; i++) {
                derivedWord[i] = static_cast<char>('a' + derivedIdx[i]);
            }
            derivedWord[derivedLen] = '\0';
            fprintf(stderr, "[AutoEnglish] RESTORE: '%s' via derived base '%s'\n", wordBuf, derivedWord); fflush(stderr);
            #endif
            return true;
        };

        // Derivational fallback for words like:
        // - responsible -> responsibility / responsibilities
        // - possible -> possibility / possibilities
        if (tryDerivedReplacement("abilities", 9, "able", 4) ||
            tryDerivedReplacement("ibilities", 9, "ible", 4) ||
            tryDerivedReplacement("ability", 7, "able", 4) ||
            tryDerivedReplacement("ibility", 7, "ible", 4)) {
            return true;
        }

        static const struct { const char* s; int len; } suffixes[] = {
            {"ing", 3},
            {"ers", 3},
            {"er", 2},
            {"ed", 2},
            {"es", 2},
            {"s", 1},
        };

        for (const auto& suf : suffixes) {
            if (stateIndex <= suf.len + 2) continue; // base too short
            if (!endsWithSuffix(idx, stateIndex, suf.s, suf.len)) continue;

            int baseLen = stateIndex - suf.len;

            // IMPROVED: Try both direct base and toneless base
            // This handles cases like "footed" with tone mark in "foot"
            bool baseFoundInEnglish = dictionaryEnglishContainsIndices(idx, baseLen);

            if (baseFoundInEnglish) {
                bool baseNonVietnameseStart = startsWithNonVietnameseCluster(idx, baseLen);
                if (baseNonVietnameseStart || !dictionaryVietnameseContainsIndices(idx, baseLen)) {
                    #ifdef DEBUG
                    fprintf(stderr, "[AutoEnglish] RESTORE: '%s' via English base + suffix '%s'\n", wordBuf, suf.s); fflush(stderr);
                    #endif
                    return true;
                }
            } else if (baseLen >= 2) {
                // Try removing tone marks from base if direct check fails
                // This handles: "footed" where "foot" has tone mark in middle
                uint8_t tonelessBase[32];
                int tonelessBaseLen = 0;

                for (int i = 0; i < baseLen; i++) {
                    uint8_t id = idx[i];
                    uint8_t nextId = (i + 1 < baseLen) ? idx[i + 1] : 0xFF;

                    // Check if next char is a tone mark
                    bool isNextToneMark = (nextId == kcToIdx[KEY_S] || nextId == kcToIdx[KEY_F] ||
                                          nextId == kcToIdx[KEY_R] || nextId == kcToIdx[KEY_X] ||
                                          nextId == kcToIdx[KEY_J] || nextId == kcToIdx[KEY_W]);

                    bool isVowel = (id == kcToIdx[KEY_A] || id == kcToIdx[KEY_E] ||
                                   id == kcToIdx[KEY_I] || id == kcToIdx[KEY_O] ||
                                   id == kcToIdx[KEY_U]);

                    tonelessBase[tonelessBaseLen++] = id;

                    if (isVowel && isNextToneMark) {
                        i++;  // Skip the tone mark
                    }
                }

                // Check toneless base version
                if (tonelessBaseLen >= 2 && tonelessBaseLen < 32) {
                    if (dictionaryEnglishContainsIndices(tonelessBase, tonelessBaseLen)) {
                        bool baseNonVietnameseStart = startsWithNonVietnameseCluster(tonelessBase, tonelessBaseLen);
                        if (baseNonVietnameseStart || !dictionaryVietnameseContainsIndices(tonelessBase, tonelessBaseLen)) {
                            #ifdef DEBUG
                            fprintf(stderr, "[AutoEnglish] RESTORE: '%s' via English base (tone removed) + suffix '%s'\n", wordBuf, suf.s); fflush(stderr);
                            #endif
                            return true;
                        }
                    }
                }
            }
        }
    }

    return isEnglish;
}

void clearEnglishDictionary() {
    phtvDictionaryClear();
}

// ============================================================================
// Custom Dictionary: User-added words
// ============================================================================

void clearCustomDictionary() {
    phtvCustomDictionaryClear();
    customEnglishWordCountCache = 0;
    customVietnameseWordCountCache = 0;
}

size_t getCustomEnglishWordCount() {
    return static_cast<size_t>(customEnglishWordCountCache);
}

size_t getCustomVietnameseWordCount() {
    return static_cast<size_t>(customVietnameseWordCountCache);
}

void initCustomDictionary(const char* jsonData, int length) {
    phtvCustomDictionaryLoadJSON(jsonData, length);
    customEnglishWordCountCache = phtvCustomDictionaryEnglishCount();
    customVietnameseWordCountCache = phtvCustomDictionaryVietnameseCount();
}
