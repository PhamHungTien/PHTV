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
// ============================================================================
bool checkIfEnglishWord(const Uint32* keyStates, int stateIndex) {
    // Quick validation
    if (!engInit | (stateIndex < 2) | (stateIndex > 30)) return false;

    // Convert keycodes to indices
    uint8_t idx[32];
    for (int i = 0; i < stateIndex; i++) {
        uint8_t id = kcToIdx[keyStates[i] & 0x3F];
        if (id >= 26) return false;
        idx[i] = id;
    }

    // PRIORITY: Check Vietnamese FIRST - if it's Vietnamese, never restore
    if (vieInit && vieNodes && searchBinaryTrie(vieNodes, idx, stateIndex)) {
        return false; // It's a Vietnamese word - do NOT restore
    }

    // Only check English if NOT Vietnamese
    return searchBinaryTrie(engNodes, idx, stateIndex);
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
