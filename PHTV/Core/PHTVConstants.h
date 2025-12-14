//
//  PHTVConstants.h
//  PHTV - Vietnamese Input Method
//
//  Created by Phạm Hùng Tiến on 2026
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//
//  Centralized Constants & Configuration
//

#ifndef PHTVConstants_h
#define PHTVConstants_h

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

#pragma mark - Bit Masks (Optimized)
// Character composition masks
#define PHTV_MASK_CAPS                          0x10000
#define PHTV_MASK_TONE                          0x20000
#define PHTV_MASK_TONE_W                        0x40000

// Mark masks (diacritics)
#define PHTV_MASK_MARK_ACUTE                    0x80000      // Sắc (á)
#define PHTV_MASK_MARK_GRAVE                    0x100000     // Huyền (à)
#define PHTV_MASK_MARK_HOOK                     0x200000     // Hỏi (ả)
#define PHTV_MASK_MARK_TILDE                    0x400000     // Ngã (ã)
#define PHTV_MASK_MARK_DOT                      0x800000     // Nặng (ạ)
#define PHTV_MASK_MARK_ALL                      0xF80000

// Character info masks
#define PHTV_MASK_CHAR_CODE                     0xFFFF
#define PHTV_MASK_STANDALONE                    0x1000000
#define PHTV_MASK_IS_CHAR_CODE                  0x2000000
#define PHTV_MASK_PURE_CHAR                     0x80000000

// Special features
#define PHTV_MASK_END_CONSONANT                 0x4000
#define PHTV_MASK_CONSONANT_ALLOWED             0x8000

#pragma mark - Modifier Keys
#define PHTV_GET_KEY(data)                      ((data) & 0xFF)
#define PHTV_HAS_CONTROL(data)                  (((data) & 0x100) != 0)
#define PHTV_HAS_OPTION(data)                   (((data) & 0x200) != 0)
#define PHTV_HAS_COMMAND(data)                  (((data) & 0x400) != 0)
#define PHTV_HAS_SHIFT(data)                    (((data) & 0x800) != 0)
#define PHTV_HAS_BEEP(data)                     (((data) & 0x8000) != 0)

#define PHTV_SET_KEY(data, key)                 ((data) = ((data) & ~0xFF) | (key))
#define PHTV_SET_CONTROL(data, val)             ((data) |= ((val) << 8))
#define PHTV_SET_OPTION(data, val)              ((data) |= ((val) << 9))
#define PHTV_SET_COMMAND(data, val)             ((data) |= ((val) << 10))

#pragma mark - Character Utilities
#define PHTV_LOW_BYTE(data)                     ((data) & 0xFF)
#define PHTV_HIGH_BYTE(data)                    (((data) >> 8) & 0xFF)
#define PHTV_GET_BOOL(data)                     ((data) ? 1 : 0)

#pragma mark - Vowel Check
#define PHTV_IS_VOWEL(code)                     \
    ((code) == KEY_A || (code) == KEY_E || (code) == KEY_U || \
     (code) == KEY_Y || (code) == KEY_I || (code) == KEY_O)

#define PHTV_IS_CONSONANT(code)                 (!PHTV_IS_VOWEL(code))

#pragma mark - Performance Optimization
// Inline functions for critical path
static inline int phtv_is_valid_range(int val, int min, int max) {
    return (val >= min && val <= max);
}

static inline int phtv_clamp(int val, int min, int max) {
    return (val < min) ? min : ((val > max) ? max : val);
}

#endif /* PHTVConstants_h */
