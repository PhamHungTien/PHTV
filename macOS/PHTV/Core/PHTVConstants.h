//
//  PHTVConstants.h
//  PHTV - Vietnamese Input Method
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//
//  Centralized Constants & Configuration
//

#ifndef PHTVConstants_h
#define PHTVConstants_h

// Single source of truth for key code + engine masks.
#include "Engine/DataType.h"
#include "PHTVHotkey.h"

#pragma mark - Application Info
#define PHTV_APP_NAME                           "PHTV"
#define PHTV_APP_FULL_NAME                      "PHTV - Bộ gõ Tiếng Việt"
#define PHTV_AUTHOR                             "Phạm Hùng Tiến"
#define PHTV_COPYRIGHT_YEAR                     "2026"
#define PHTV_VERSION                            "1.0"
#define PHTV_BUILD                              "1"

#pragma mark - Engine Configuration
#define PHTV_DEBUG_MODE                         0
#define PHTV_MAX_UNICODE_STRING                 256
#define PHTV_MAX_BUFFER_SIZE                    1024

#pragma mark - Input Methods
typedef enum : int {
    PHTVInputMethodEnglish = 0,
    PHTVInputMethodVietnamese = 1
} PHTVInputMethod;

typedef enum : int {
    PHTVInputTypeTelex = 0,
    PHTVInputTypeVNI = 1,
    PHTVInputTypeSimpleTelex1 = 2,
    PHTVInputTypeSimpleTelex2 = 3
} PHTVInputType;

typedef enum : int {
    PHTVCodeTableUnicode = 0,
    PHTVCodeTableTCVN3 = 1,
    PHTVCodeTableVNIWindows = 2,
    PHTVCodeTableUnicodeComposite = 3,
    PHTVCodeTableCP1258 = 4
} PHTVCodeTable;

#pragma mark - Feature Flags
typedef enum : int {
    PHTVFeatureDisabled = 0,
    PHTVFeatureEnabled = 1
} PHTVFeatureState;

#pragma mark - Processing States
typedef enum : int {
    PHTVProcessUnknown = 0,
    PHTVProcessVowel,
    PHTVProcessTone,
    PHTVProcessMark,
    PHTVProcessConsonant,
    PHTVProcessEndConsonant,
    PHTVProcessModifyWord,
    PHTVProcessRestore,
    PHTVProcessMacro,
    PHTVProcessNewSession
} PHTVProcessState;

#pragma mark - Bit Masks (Engine-aligned)
// Character composition masks
#define PHTV_MASK_CAPS                          CAPS_MASK
#define PHTV_MASK_TONE                          TONE_MASK
#define PHTV_MASK_TONE_W                        TONEW_MASK

// Mark masks (diacritics)
#define PHTV_MASK_MARK_ACUTE                    MARK1_MASK
#define PHTV_MASK_MARK_GRAVE                    MARK2_MASK
#define PHTV_MASK_MARK_HOOK                     MARK3_MASK
#define PHTV_MASK_MARK_TILDE                    MARK4_MASK
#define PHTV_MASK_MARK_DOT                      MARK5_MASK
#define PHTV_MASK_MARK_ALL                      MARK_MASK

// Character info masks
#define PHTV_MASK_CHAR_CODE                     CHAR_MASK
#define PHTV_MASK_STANDALONE                    STANDALONE_MASK
#define PHTV_MASK_IS_CHAR_CODE                  CHAR_CODE_MASK
#define PHTV_MASK_PURE_CHAR                     PURE_CHARACTER_MASK

// Special features
#define PHTV_MASK_END_CONSONANT                 END_CONSONANT_MASK
#define PHTV_MASK_CONSONANT_ALLOWED             CONSONANT_ALLOW_MASK

#pragma mark - Modifier Keys
#define PHTV_GET_KEY(data)                      GET_SWITCH_KEY(data)
#define PHTV_GET_BOOL(data)                     GET_BOOL(data)

#define PHTV_HAS_CONTROL(data)                  HAS_CONTROL(data)
#define PHTV_HAS_OPTION(data)                   HAS_OPTION(data)
#define PHTV_HAS_COMMAND(data)                  HAS_COMMAND(data)
#define PHTV_HAS_SHIFT(data)                    HAS_SHIFT(data)
#define PHTV_HAS_BEEP(data)                     HAS_BEEP(data)
#define PHTV_DEFAULT_SWITCH_STATUS              PHTV_DEFAULT_SWITCH_HOTKEY_STATUS

#define PHTV_SET_KEY(data, key)                 SET_SWITCH_KEY(data, key)
#define PHTV_SET_CONTROL(data, val)             SET_CONTROL_KEY(data, val)
#define PHTV_SET_OPTION(data, val)              SET_OPTION_KEY(data, val)
#define PHTV_SET_COMMAND(data, val)             SET_COMMAND_KEY(data, val)
#define PHTV_SET_SHIFT(data, val)               SET_SHIFT_KEY(data, val)
#define PHTV_SET_BEEP(data, val)                SET_BEEP_KEY(data, val)

#pragma mark - Character Utilities
#define PHTV_LOW_BYTE(data)                     ((data) & 0xFF)
#define PHTV_HIGH_BYTE(data)                    (((data) >> 8) & 0xFF)

#pragma mark - Vowel Check
#define PHTV_IS_VOWEL(code)                     \
    ((code) == KEY_A || (code) == KEY_E || (code) == KEY_U || \
     (code) == KEY_Y || (code) == KEY_I || (code) == KEY_O)

#define PHTV_IS_CONSONANT(code)                 (!PHTV_IS_VOWEL(code))

#pragma mark - Performance Helpers
static inline int phtv_is_valid_range(int val, int min, int max) {
    return (val >= min && val <= max);
}

static inline int phtv_clamp(int val, int min, int max) {
    return (val < min) ? min : ((val > max) ? max : val);
}

static inline int phtv_is_valid_code_table(int codeTable) {
    return phtv_is_valid_range(codeTable, PHTVCodeTableUnicode, PHTVCodeTableCP1258);
}

static inline int phtv_clamp_code_table(int codeTable) {
    return phtv_clamp(codeTable, PHTVCodeTableUnicode, PHTVCodeTableCP1258);
}

#endif /* PHTVConstants_h */
