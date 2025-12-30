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
#include <cstring>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <unordered_set>
#include <cstdio>

#ifdef __APPLE__
#include "../Platforms/mac.h"
#else
#include "../Platforms/windows.h"
#endif

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
static bool engInit = false;
static bool vieInit = false;

// Memory mapped file data
static void* engMmap = nullptr;
static void* vieMmap = nullptr;
static size_t engMmapSize = 0;
static size_t vieMmapSize = 0;

// Pre-computed lookup table: keycode -> letter index (0-25), 255 = invalid
alignas(64) static uint8_t kcToIdx[64];
static bool kcInit = false;

// Custom dictionary: user-added words for better accuracy
static std::unordered_set<std::string> customEnglishWords;
static std::unordered_set<std::string> customVietnameseWords;

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
// Load binary trie using mmap for instant access
// ============================================================================
static bool loadBinaryTrie(const char* path,
                           void*& mmapPtr, size_t& mmapSize,
                           const BinaryTrieNode*& nodes,
                           uint32_t& nodeCount, size_t& wordCount) {
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
}

// ============================================================================
// Public API
// ============================================================================
bool initEnglishDictionary(const string& filePath) {
    if (engInit) return true;
    initKcLookup();

    // Convert path to .bin
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

    // Try _dict suffix
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

bool initVietnameseDictionary(const string& filePath) {
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

bool isEnglishDictionaryInitialized() { return engInit; }
size_t getEnglishDictionarySize() { return engWordCount; }
size_t getVietnameseDictionarySize() { return vieWordCount; }

bool isEnglishWord(const string& word) {
    if (!engInit || !engNodes || word.empty()) return false;
    uint8_t idx[32];
    int len = 0;
    for (size_t i = 0; i < word.length() && len < 30; i++) {
        char c = word[i];
        if (c >= 'a' && c <= 'z') idx[len++] = c - 'a';
        else if (c >= 'A' && c <= 'Z') idx[len++] = c - 'A';
        else return false;
    }
    return searchBinaryTrie(engNodes, idx, len);
}

string keyStatesToString(const Uint32* keyCodes, int count) {
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
    if (!engInit) {
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
    if (!customVietnameseWords.empty() && customVietnameseWords.count(word)) {
        #ifdef DEBUG
        fprintf(stderr, "[AutoEnglish] SKIP: '%s' is in custom Vietnamese dictionary\n", word.c_str()); fflush(stderr);
        #endif
        return false; // User explicitly marked as Vietnamese - do NOT restore
    }

    // PRIORITY 2: Check custom English - if user marked as English, always restore
    if (!customEnglishWords.empty() && customEnglishWords.count(word)) {
        #ifdef DEBUG
        fprintf(stderr, "[AutoEnglish] RESTORE: '%s' is in custom English dictionary\n", word.c_str()); fflush(stderr);
        #endif
        return true; // User explicitly marked as English - restore
    }

    // PRIORITY 3: Check built-in Vietnamese dictionary
    if (vieInit && vieNodes && searchBinaryTrie(vieNodes, idx, stateIndex)) {
        #ifdef DEBUG
        fprintf(stderr, "[AutoEnglish] SKIP: '%s' found in Vietnamese dictionary\n", word.c_str()); fflush(stderr);
        #endif
        return false; // It's a Vietnamese word - do NOT restore
    }

    // PRIORITY 4: Check built-in English dictionary
    bool isEnglish = searchBinaryTrie(engNodes, idx, stateIndex);
    #ifdef DEBUG
    if (isEnglish) {
        fprintf(stderr, "[AutoEnglish] RESTORE: '%s' found in English dictionary\n", word.c_str()); fflush(stderr);
    } else {
        fprintf(stderr, "[AutoEnglish] SKIP: '%s' not found in English dictionary\n", word.c_str()); fflush(stderr);
    }
    #endif
    return isEnglish;
}

void clearEnglishDictionary() {
    if (engMmap) {
        munmap(engMmap, engMmapSize);
        engMmap = nullptr;
        engNodes = nullptr;
    }
    if (vieMmap) {
        munmap(vieMmap, vieMmapSize);
        vieMmap = nullptr;
        vieNodes = nullptr;
    }
    engInit = vieInit = false;
    engWordCount = vieWordCount = 0;
    engNodeCount = vieNodeCount = 0;
}

// ============================================================================
// Custom Dictionary: User-added words
// ============================================================================

void clearCustomDictionary() {
    customEnglishWords.clear();
    customVietnameseWords.clear();
}

size_t getCustomEnglishWordCount() {
    return customEnglishWords.size();
}

size_t getCustomVietnameseWordCount() {
    return customVietnameseWords.size();
}

// Simple JSON parser for custom dictionary
// Expected format: [{"word":"abc","type":"en"},...]
void initCustomDictionary(const char* jsonData, int length) {
    clearCustomDictionary();

    if (!jsonData || length < 2) return;

    std::string json(jsonData, length);
    size_t pos = 0;

    while (pos < json.length()) {
        // Find "word":"
        size_t wordKeyPos = json.find("\"word\":", pos);
        if (wordKeyPos == std::string::npos) break;

        // Find the word value
        size_t wordStart = json.find("\"", wordKeyPos + 7);
        if (wordStart == std::string::npos) break;
        wordStart++; // Skip opening quote

        size_t wordEnd = json.find("\"", wordStart);
        if (wordEnd == std::string::npos) break;

        std::string word = json.substr(wordStart, wordEnd - wordStart);

        // Find "type":"
        size_t typeKeyPos = json.find("\"type\":", wordEnd);
        if (typeKeyPos == std::string::npos) {
            pos = wordEnd + 1;
            continue;
        }

        size_t typeStart = json.find("\"", typeKeyPos + 7);
        if (typeStart == std::string::npos) break;
        typeStart++; // Skip opening quote

        size_t typeEnd = json.find("\"", typeStart);
        if (typeEnd == std::string::npos) break;

        std::string type = json.substr(typeStart, typeEnd - typeStart);

        // Convert word to lowercase
        for (size_t i = 0; i < word.length(); i++) {
            if (word[i] >= 'A' && word[i] <= 'Z') {
                word[i] = word[i] - 'A' + 'a';
            }
        }

        // Add to appropriate set
        if (type == "en" || type == "english") {
            customEnglishWords.insert(word);
        } else if (type == "vi" || type == "vietnamese") {
            customVietnameseWords.insert(word);
        }

        pos = typeEnd + 1;
    }
}
