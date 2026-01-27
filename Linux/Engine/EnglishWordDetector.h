//
//  EnglishWordDetector.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//
//  Ultra-fast English word detection using memory-mapped binary trie
//  O(1) load time + O(k) lookup where k = word length
//

#ifndef EnglishWordDetector_h
#define EnglishWordDetector_h

#include <string>
#include "DataType.h"

using namespace std;

/**
 * Auto English Restore Feature
 * Detects when user types an English word in Vietnamese mode and auto-restores it.
 * Example: typing "tẻminal" → restores to "terminal"
 *
 * Uses pre-built binary trie (PHT2 format) for instant loading and lookup.
 */

/**
 * Initialize the English word dictionary from a file
 * @param filePath Path to the dictionary file (one word per line)
 * @return true if loaded successfully
 */
bool initEnglishDictionary(const string& filePath);

/**
 * Initialize the Vietnamese word dictionary from a file
 * Used to exclude Vietnamese words from English restoration
 * @param filePath Path to the dictionary file (one word per line, with or without diacritics)
 * @return true if loaded successfully
 */
bool initVietnameseDictionary(const string& filePath);

/**
 * Check if the dictionary has been initialized
 */
bool isEnglishDictionaryInitialized();

/**
 * Get the number of words in the dictionary
 */
size_t getEnglishDictionarySize();

/**
 * Get the number of words in the Vietnamese dictionary
 */
size_t getVietnameseDictionarySize();

/**
 * Check if a word exists in the English dictionary
 * @param word The word to check (lowercase)
 * @return true if the word exists
 */
bool isEnglishWord(const string& word);

/**
 * Convert key codes (from KeyStates) to ASCII string
 * @param keyCodes Array of key codes with optional CAPS_MASK
 * @param count Number of key codes
 * @return The ASCII string representation
 */
string keyStatesToString(const Uint32* keyCodes, int count);

/**
 * Check if the current typed word (from KeyStates) should be restored to English
 * Returns true only if word is in English dictionary AND NOT in Vietnamese dictionary
 * @param keyStates Array of raw key states
 * @param stateIndex Number of keys in the array
 * @return true if the word should be restored to English
 */
bool checkIfEnglishWord(const Uint32* keyStates, int stateIndex);

/**
 * Clear all dictionaries (for cleanup)
 */
void clearEnglishDictionary();

/**
 * Initialize custom dictionary from JSON data
 * JSON format: [{"word": "vinfast", "type": "en"}, {"word": "xin", "type": "vi"}]
 * @param jsonData JSON string containing custom words
 * @param length Length of JSON string
 */
void initCustomDictionary(const char* jsonData, int length);

/**
 * Clear custom dictionary
 */
void clearCustomDictionary();

/**
 * Get custom dictionary word count
 */
size_t getCustomEnglishWordCount();
size_t getCustomVietnameseWordCount();

#endif /* EnglishWordDetector_h */
