// PHTVVietnameseData.swift
// PHTV
//
// Ported from VietnameseData.inc + EngineDataTypes.inc + EngineMacKeyCodes.inc + EngineInternalMasks.inc
// Created by Phạm Hùng Tiến on 2026.

// MARK: - Constants

let ENGINE_MAX_BUFF: Int = 32

// MARK: - Key codes (Mac virtual key codes)

let KEY_ESC: UInt16   = 53
let KEY_DELETE: UInt16 = 51
let KEY_TAB: UInt16   = 48
let KEY_ENTER: UInt16 = 76
let KEY_RETURN: UInt16 = 36
let KEY_SPACE: UInt16 = 49
let KEY_LEFT: UInt16  = 123
let KEY_RIGHT: UInt16 = 124
let KEY_DOWN: UInt16  = 125
let KEY_UP: UInt16    = 126
let KEY_HOME: UInt16  = 115
let KEY_PAGE_UP: UInt16 = 116
let KEY_FORWARD_DELETE: UInt16 = 117
let KEY_END: UInt16   = 119
let KEY_PAGE_DOWN: UInt16 = 121

let KEY_EMPTY: UInt16 = 256
let KEY_A: UInt16 = 0
let KEY_B: UInt16 = 11
let KEY_C: UInt16 = 8
let KEY_D: UInt16 = 2
let KEY_E: UInt16 = 14
let KEY_F: UInt16 = 3
let KEY_G: UInt16 = 5
let KEY_H: UInt16 = 4
let KEY_I: UInt16 = 34
let KEY_J: UInt16 = 38
let KEY_K: UInt16 = 40
let KEY_L: UInt16 = 37
let KEY_M: UInt16 = 46
let KEY_N: UInt16 = 45
let KEY_O: UInt16 = 31
let KEY_P: UInt16 = 35
let KEY_Q: UInt16 = 12
let KEY_R: UInt16 = 15
let KEY_S: UInt16 = 1
let KEY_T: UInt16 = 17
let KEY_U: UInt16 = 32
let KEY_V: UInt16 = 9
let KEY_W: UInt16 = 13
let KEY_X: UInt16 = 7
let KEY_Y: UInt16 = 16
let KEY_Z: UInt16 = 6

let KEY_1: UInt16 = 18
let KEY_2: UInt16 = 19
let KEY_3: UInt16 = 20
let KEY_4: UInt16 = 21
let KEY_5: UInt16 = 23
let KEY_6: UInt16 = 22
let KEY_7: UInt16 = 26
let KEY_8: UInt16 = 28
let KEY_9: UInt16 = 25
let KEY_0: UInt16 = 29

let KEY_LEFT_BRACKET: UInt16  = 33
let KEY_RIGHT_BRACKET: UInt16 = 30
let KEY_LEFT_SHIFT: UInt16    = 57
let KEY_RIGHT_SHIFT: UInt16   = 60
let KEY_DOT: UInt16           = 47
let KEY_BACKQUOTE: UInt16     = 50
let KEY_MINUS: UInt16         = 27
let KEY_EQUALS: UInt16        = 24
let KEY_BACK_SLASH: UInt16    = 42
let KEY_SEMICOLON: UInt16     = 41
let KEY_QUOTE: UInt16         = 39
let KEY_COMMA: UInt16         = 43
let KEY_SLASH: UInt16         = 44

let KEY_LEFT_COMMAND: UInt16  = 55
let KEY_RIGHT_COMMAND: UInt16 = 54
let KEY_LEFT_CONTROL: UInt16  = 59
let KEY_RIGHT_CONTROL: UInt16 = 62
let KEY_LEFT_OPTION: UInt16   = 58
let KEY_RIGHT_OPTION: UInt16  = 61
let KEY_FUNCTION: UInt16      = 63

// MARK: - Bit masks

let CAPS_MASK: UInt32       = 0x10000
let TONE_MASK: UInt32       = 0x20000
let TONEW_MASK: UInt32      = 0x40000
let MARK1_MASK: UInt32      = 0x80000
let MARK2_MASK: UInt32      = 0x100000
let MARK3_MASK: UInt32      = 0x200000
let MARK4_MASK: UInt32      = 0x400000
let MARK5_MASK: UInt32      = 0x800000
let MARK_MASK: UInt32       = 0xF80000
let CHAR_MASK: UInt32       = 0xFFFF
let STANDALONE_MASK: UInt32 = 0x1000000
let CHAR_CODE_MASK: UInt32  = 0x2000000
let PURE_CHARACTER_MASK: UInt32 = 0x80000000
let END_CONSONANT_MASK: UInt16  = 0x4000
let CONSONANT_ALLOW_MASK: UInt16 = 0x8000

// MARK: - Inline helpers

@inline(__always)
func isConsonant(_ k: UInt16) -> Bool {
    k != KEY_A && k != KEY_E && k != KEY_U && k != KEY_Y && k != KEY_I && k != KEY_O
}

@inline(__always)
func chrOf(_ tw: UInt32) -> UInt16 { UInt16(tw & CHAR_MASK) }

@inline(__always)
func isArrowKey(_ k: Int) -> Bool {
    k == Int(KEY_LEFT) || k == Int(KEY_RIGHT) || k == Int(KEY_UP) || k == Int(KEY_DOWN)
}

@inline(__always)
func isNavigationKey(_ k: Int) -> Bool {
    isArrowKey(k) || k == Int(KEY_HOME) || k == Int(KEY_END) ||
    k == Int(KEY_PAGE_UP) || k == Int(KEY_PAGE_DOWN)
}

@inline(__always)
func isModifierKey(_ k: Int) -> Bool {
    k == Int(KEY_LEFT_SHIFT) || k == Int(KEY_RIGHT_SHIFT) ||
    k == Int(KEY_LEFT_COMMAND) || k == Int(KEY_RIGHT_COMMAND) ||
    k == Int(KEY_LEFT_CONTROL) || k == Int(KEY_RIGHT_CONTROL) ||
    k == Int(KEY_LEFT_OPTION) || k == Int(KEY_RIGHT_OPTION) ||
    k == Int(KEY_FUNCTION)
}

@inline(__always)
func isNumberKey(_ k: UInt16) -> Bool {
    k == KEY_1 || k == KEY_2 || k == KEY_3 || k == KEY_4 || k == KEY_5 ||
    k == KEY_6 || k == KEY_7 || k == KEY_8 || k == KEY_9 || k == KEY_0
}

// MARK: - Input type enum

enum VKeyInputType: Int32 {
    case telex       = 0
    case vni         = 1
    case simpleTelex1 = 2
    case simpleTelex2 = 3
}

enum VKeyEvent: Int32 {
    case keyboard = 0
    case mouse    = 1
}

enum VKeyEventState: Int32 {
    case keyDown   = 0
    case keyUp     = 1
    case mouseDown = 2
    case mouseUp   = 3
}

enum HookCodeState: Int32 {
    case doNothing              = 0
    case willProcess            = 1
    case breakWord              = 2
    case restore                = 3
    case replaceMacro           = 4
    case restoreAndStartNewSession = 5
}

// MARK: - Vietnamese data tables

/// douKey: double-vowel key pairs used for vowel substitution (a→â, e→ê)
let douKey: [(UInt16, UInt16)] = [
    (KEY_A, 0xE2),
    (KEY_E, 0xEA)
]

/// Vowel patterns for vowel-based key handling
let vnVowelPatterns: [UInt16: [[UInt16]]] = [
    KEY_A: [
        [KEY_A, KEY_N, KEY_G], [KEY_A, KEY_G | END_CONSONANT_MASK],
        [KEY_A, KEY_N],
        [KEY_A, KEY_M],
        [KEY_A, KEY_U],
        [KEY_A, KEY_Y],
        [KEY_A, KEY_T],
        [KEY_A, KEY_P],
        [KEY_A],
        [KEY_A, KEY_C],
    ],
    KEY_O: [
        [KEY_O, KEY_N, KEY_G], [KEY_O, KEY_G | END_CONSONANT_MASK],
        [KEY_O, KEY_N],
        [KEY_O, KEY_M],
        [KEY_O, KEY_I],
        [KEY_O, KEY_C],
        [KEY_O, KEY_T],
        [KEY_O, KEY_P],
        [KEY_O],
    ],
    KEY_E: [
        [KEY_E, KEY_N, KEY_H], [KEY_E, KEY_H | END_CONSONANT_MASK],
        [KEY_E, KEY_N, KEY_G], [KEY_E, KEY_G | END_CONSONANT_MASK],
        [KEY_E, KEY_C, KEY_H], [KEY_E, KEY_K | END_CONSONANT_MASK],
        [KEY_E, KEY_C],
        [KEY_E, KEY_T],
        [KEY_E, KEY_Y],
        [KEY_E, KEY_U],
        [KEY_E, KEY_P],
        [KEY_E, KEY_C],
        [KEY_E, KEY_N],
        [KEY_E, KEY_M],
        [KEY_E],
    ],
    KEY_W: [
        [KEY_O, KEY_N],
        [KEY_U, KEY_O, KEY_N, KEY_G], [KEY_U, KEY_O, KEY_G | END_CONSONANT_MASK],
        [KEY_U, KEY_O, KEY_N],
        [KEY_U, KEY_O, KEY_I],
        [KEY_U, KEY_O, KEY_C],
        [KEY_O, KEY_I],
        [KEY_O, KEY_P],
        [KEY_O, KEY_M],
        [KEY_O, KEY_A],
        [KEY_O, KEY_T],
        [KEY_U, KEY_N, KEY_G], [KEY_U, KEY_G | END_CONSONANT_MASK],
        [KEY_A, KEY_N, KEY_G], [KEY_A, KEY_G | END_CONSONANT_MASK],
        [KEY_U, KEY_N],
        [KEY_U, KEY_M],
        [KEY_U, KEY_C],
        [KEY_U, KEY_A],
        [KEY_U, KEY_I],
        [KEY_U, KEY_T],
        [KEY_U],
        [KEY_A, KEY_P],
        [KEY_A, KEY_T],
        [KEY_A, KEY_M],
        [KEY_A, KEY_N],
        [KEY_A],
        [KEY_A, KEY_C],
        [KEY_A, KEY_C, KEY_H], [KEY_A, KEY_K | END_CONSONANT_MASK],
        [KEY_O],
        [KEY_U, KEY_U],
    ],
]

/// Vowel combination rules for mark placement
let vnVowelCombine: [UInt16: [[UInt32]]] = [
    KEY_A: [
        [0, UInt32(KEY_A), UInt32(KEY_I)],
        [0, UInt32(KEY_A), UInt32(KEY_O)],
        [0, UInt32(KEY_A), UInt32(KEY_U)],
        [0, UInt32(KEY_A) | TONE_MASK, UInt32(KEY_U)],
        [0, UInt32(KEY_A), UInt32(KEY_Y)],
        [0, UInt32(KEY_A) | TONE_MASK, UInt32(KEY_Y)],
    ],
    KEY_E: [
        [0, UInt32(KEY_E), UInt32(KEY_O)],
        [0, UInt32(KEY_E) | TONE_MASK, UInt32(KEY_U)],
    ],
    KEY_I: [
        [1, UInt32(KEY_I), UInt32(KEY_E) | TONE_MASK, UInt32(KEY_U)],
        [0, UInt32(KEY_I), UInt32(KEY_A)],
        [1, UInt32(KEY_I), UInt32(KEY_E) | TONE_MASK],
        [0, UInt32(KEY_I), UInt32(KEY_U)],
    ],
    KEY_O: [
        [0, UInt32(KEY_O), UInt32(KEY_A), UInt32(KEY_I)],
        [0, UInt32(KEY_O), UInt32(KEY_A), UInt32(KEY_O)],
        [0, UInt32(KEY_O), UInt32(KEY_A), UInt32(KEY_Y)],
        [0, UInt32(KEY_O), UInt32(KEY_E), UInt32(KEY_O)],
        [1, UInt32(KEY_O), UInt32(KEY_A)],
        [1, UInt32(KEY_O), UInt32(KEY_A) | TONEW_MASK],
        [1, UInt32(KEY_O), UInt32(KEY_E)],
        [0, UInt32(KEY_O), UInt32(KEY_I)],
        [0, UInt32(KEY_O) | TONE_MASK, UInt32(KEY_I)],
        [0, UInt32(KEY_O) | TONEW_MASK, UInt32(KEY_I)],
        [1, UInt32(KEY_O), UInt32(KEY_O)],
        [1, UInt32(KEY_O) | TONE_MASK, UInt32(KEY_O) | TONE_MASK],
    ],
    KEY_U: [
        [0, UInt32(KEY_U), UInt32(KEY_Y), UInt32(KEY_U)],
        [1, UInt32(KEY_U), UInt32(KEY_Y), UInt32(KEY_E) | TONE_MASK],
        [0, UInt32(KEY_U), UInt32(KEY_Y), UInt32(KEY_A)],
        [0, UInt32(KEY_U) | TONEW_MASK, UInt32(KEY_O) | TONEW_MASK, UInt32(KEY_U)],
        [0, UInt32(KEY_U) | TONEW_MASK, UInt32(KEY_O) | TONEW_MASK, UInt32(KEY_I)],
        [0, UInt32(KEY_U), UInt32(KEY_O) | TONE_MASK, UInt32(KEY_I)],
        [0, UInt32(KEY_U), UInt32(KEY_A) | TONE_MASK, UInt32(KEY_Y)],
        [1, UInt32(KEY_U), UInt32(KEY_A), UInt32(KEY_O)],
        [1, UInt32(KEY_U), UInt32(KEY_A)],
        [1, UInt32(KEY_U), UInt32(KEY_A) | TONEW_MASK],
        [1, UInt32(KEY_U), UInt32(KEY_A) | TONE_MASK],
        [0, UInt32(KEY_U) | TONEW_MASK, UInt32(KEY_A)],
        [1, UInt32(KEY_U), UInt32(KEY_E) | TONE_MASK],
        [0, UInt32(KEY_U), UInt32(KEY_I)],
        [0, UInt32(KEY_U) | TONEW_MASK, UInt32(KEY_I)],
        [1, UInt32(KEY_U), UInt32(KEY_O)],
        [1, UInt32(KEY_U), UInt32(KEY_O) | TONE_MASK],
        [0, UInt32(KEY_U), UInt32(KEY_O) | TONEW_MASK],
        [1, UInt32(KEY_U) | TONEW_MASK, UInt32(KEY_O) | TONEW_MASK],
        [0, UInt32(KEY_U) | TONEW_MASK, UInt32(KEY_U)],
        [1, UInt32(KEY_U), UInt32(KEY_Y)],
    ],
    KEY_Y: [
        [0, UInt32(KEY_Y), UInt32(KEY_E) | TONE_MASK, UInt32(KEY_U)],
        [1, UInt32(KEY_Y), UInt32(KEY_E) | TONE_MASK],
    ],
]

/// Consonant D patterns
let vnConsonantD: [[UInt16]] = [
    [KEY_D, KEY_E, KEY_N, KEY_H], [KEY_D, KEY_E, KEY_H | END_CONSONANT_MASK],
    [KEY_D, KEY_E, KEY_N, KEY_G], [KEY_D, KEY_E, KEY_G | END_CONSONANT_MASK],
    [KEY_D, KEY_E, KEY_C, KEY_H], [KEY_D, KEY_E, KEY_K | END_CONSONANT_MASK],
    [KEY_D, KEY_E, KEY_N],
    [KEY_D, KEY_E, KEY_C],
    [KEY_D, KEY_E, KEY_M],
    [KEY_D, KEY_E],
    [KEY_D, KEY_E, KEY_T],
    [KEY_D, KEY_E, KEY_U],
    [KEY_D, KEY_E, KEY_O],
    [KEY_D, KEY_E, KEY_P],
    [KEY_D, KEY_U, KEY_N, KEY_G], [KEY_D, KEY_U, KEY_G | END_CONSONANT_MASK],
    [KEY_D, KEY_U, KEY_N],
    [KEY_D, KEY_U, KEY_M],
    [KEY_D, KEY_U, KEY_C],
    [KEY_D, KEY_U, KEY_O],
    [KEY_D, KEY_U, KEY_A],
    [KEY_D, KEY_U, KEY_O, KEY_I],
    [KEY_D, KEY_U, KEY_O, KEY_C],
    [KEY_D, KEY_U, KEY_O, KEY_N],
    [KEY_D, KEY_U, KEY_O, KEY_N, KEY_G], [KEY_D, KEY_U, KEY_O, KEY_G | END_CONSONANT_MASK],
    [KEY_D, KEY_U],
    [KEY_D, KEY_U, KEY_P],
    [KEY_D, KEY_U, KEY_T],
    [KEY_D, KEY_U, KEY_I],
    [KEY_D, KEY_I, KEY_C, KEY_H], [KEY_D, KEY_I, KEY_K | END_CONSONANT_MASK],
    [KEY_D, KEY_I, KEY_C],
    [KEY_D, KEY_I, KEY_N, KEY_H], [KEY_D, KEY_I, KEY_H | END_CONSONANT_MASK],
    [KEY_D, KEY_I, KEY_N],
    [KEY_D, KEY_I],
    [KEY_D, KEY_I, KEY_A],
    [KEY_D, KEY_I, KEY_E],
    [KEY_D, KEY_I, KEY_E, KEY_C],
    [KEY_D, KEY_I, KEY_E, KEY_U],
    [KEY_D, KEY_I, KEY_E, KEY_N],
    [KEY_D, KEY_I, KEY_E, KEY_M],
    [KEY_D, KEY_I, KEY_E, KEY_P],
    [KEY_D, KEY_I, KEY_T],
    [KEY_D, KEY_O],
    [KEY_D, KEY_O, KEY_A],
    [KEY_D, KEY_O, KEY_A, KEY_N],
    [KEY_D, KEY_O, KEY_A, KEY_N, KEY_G], [KEY_D, KEY_O, KEY_A, KEY_G | END_CONSONANT_MASK],
    [KEY_D, KEY_O, KEY_A, KEY_N, KEY_H], [KEY_D, KEY_O, KEY_A, KEY_H | END_CONSONANT_MASK],
    [KEY_D, KEY_O, KEY_A, KEY_M],
    [KEY_D, KEY_O, KEY_E],
    [KEY_D, KEY_O, KEY_I],
    [KEY_D, KEY_O, KEY_P],
    [KEY_D, KEY_O, KEY_C],
    [KEY_D, KEY_O, KEY_N],
    [KEY_D, KEY_O, KEY_N, KEY_G], [KEY_D, KEY_O, KEY_G | END_CONSONANT_MASK],
    [KEY_D, KEY_O, KEY_M],
    [KEY_D, KEY_O, KEY_T],
    [KEY_D, KEY_A],
    [KEY_D, KEY_A, KEY_T],
    [KEY_D, KEY_A, KEY_Y],
    [KEY_D, KEY_A, KEY_U],
    [KEY_D, KEY_A, KEY_I],
    [KEY_D, KEY_A, KEY_O],
    [KEY_D, KEY_A, KEY_P],
    [KEY_D, KEY_A, KEY_C],
    [KEY_D, KEY_A, KEY_C, KEY_H], [KEY_D, KEY_A, KEY_K | END_CONSONANT_MASK],
    [KEY_D, KEY_A, KEY_N],
    [KEY_D, KEY_A, KEY_N, KEY_H], [KEY_D, KEY_A, KEY_H | END_CONSONANT_MASK],
    [KEY_D, KEY_A, KEY_N, KEY_G], [KEY_D, KEY_A, KEY_G | END_CONSONANT_MASK],
    [KEY_D, KEY_A, KEY_M],
    [KEY_D],
]

/// Vowel patterns for mark placement
let vnVowelForMark: [UInt16: [[UInt16]]] = [
    KEY_A: [
        [KEY_A, KEY_N, KEY_G], [KEY_A, KEY_G | END_CONSONANT_MASK],
        [KEY_A, KEY_N],
        [KEY_A, KEY_N, KEY_H], [KEY_A, KEY_H | END_CONSONANT_MASK],
        [KEY_A, KEY_M],
        [KEY_A, KEY_U],
        [KEY_A, KEY_Y],
        [KEY_A, KEY_T],
        [KEY_A, KEY_P],
        [KEY_A],
        [KEY_A, KEY_C],
        [KEY_A, KEY_I],
        [KEY_A, KEY_O],
        [KEY_A, KEY_C, KEY_H], [KEY_A, KEY_K | END_CONSONANT_MASK],
    ],
    KEY_O: [
        [KEY_O, KEY_O, KEY_N, KEY_G], [KEY_O, KEY_O, KEY_G | END_CONSONANT_MASK],
        [KEY_O, KEY_N, KEY_G], [KEY_O, KEY_G | END_CONSONANT_MASK],
        [KEY_O, KEY_O, KEY_N],
        [KEY_O, KEY_O, KEY_C],
        [KEY_O, KEY_O],
        [KEY_O, KEY_N],
        [KEY_O, KEY_M],
        [KEY_O, KEY_I],
        [KEY_O, KEY_C],
        [KEY_O, KEY_T],
        [KEY_O, KEY_P],
        [KEY_O],
    ],
    KEY_E: [
        [KEY_E, KEY_N, KEY_H], [KEY_E, KEY_H | END_CONSONANT_MASK],
        [KEY_E, KEY_N, KEY_G], [KEY_E, KEY_G | END_CONSONANT_MASK],
        [KEY_E, KEY_C, KEY_H], [KEY_E, KEY_K | END_CONSONANT_MASK],
        [KEY_E, KEY_C],
        [KEY_E, KEY_T],
        [KEY_E, KEY_Y],
        [KEY_E, KEY_U],
        [KEY_E, KEY_P],
        [KEY_E, KEY_C],
        [KEY_E, KEY_N],
        [KEY_E, KEY_M],
        [KEY_E],
    ],
    KEY_I: [
        [KEY_I, KEY_N, KEY_H], [KEY_I, KEY_H | END_CONSONANT_MASK],
        [KEY_I, KEY_C, KEY_H], [KEY_I, KEY_K | END_CONSONANT_MASK],
        [KEY_I, KEY_N],
        [KEY_I, KEY_T],
        [KEY_I, KEY_U],
        [KEY_I, KEY_U, KEY_P],
        [KEY_I, KEY_N],
        [KEY_I, KEY_M],
        [KEY_I, KEY_P],
        [KEY_I, KEY_A],
        [KEY_I, KEY_C],
        [KEY_I],
    ],
    KEY_U: [
        [KEY_U, KEY_N, KEY_G], [KEY_U, KEY_G | END_CONSONANT_MASK],
        [KEY_U, KEY_I],
        [KEY_U, KEY_O],
        [KEY_U, KEY_Y],
        [KEY_U, KEY_Y, KEY_N],
        [KEY_U, KEY_Y, KEY_T],
        [KEY_U, KEY_Y, KEY_P],
        [KEY_U, KEY_Y, KEY_N, KEY_H], [KEY_U, KEY_Y, KEY_H | END_CONSONANT_MASK],
        [KEY_U, KEY_T],
        [KEY_U, KEY_U],
        [KEY_U, KEY_A],
        [KEY_U, KEY_I],
        [KEY_U, KEY_C],
        [KEY_U, KEY_N],
        [KEY_U, KEY_M],
        [KEY_U, KEY_P],
        [KEY_U],
    ],
    KEY_Y: [
        [KEY_Y],
    ],
]

/// Initial consonant table
let vnConsonantTable: [[UInt16]] = [
    [KEY_N, KEY_G, KEY_H],
    [KEY_P, KEY_H],
    [KEY_T, KEY_H],
    [KEY_T, KEY_R],
    [KEY_G, KEY_I],
    [KEY_C, KEY_H],
    [KEY_N, KEY_H],
    [KEY_N, KEY_G],
    [KEY_K, KEY_H],
    [KEY_G, KEY_H],
    [KEY_G],
    [KEY_C],
    [KEY_Q],
    [KEY_K],
    [KEY_T],
    [KEY_R],
    [KEY_H],
    [KEY_B],
    [KEY_M],
    [KEY_V],
    [KEY_N],
    [KEY_L],
    [KEY_X],
    [KEY_P],
    [KEY_S],
    [KEY_D],
    [KEY_F | CONSONANT_ALLOW_MASK],
    [KEY_W | CONSONANT_ALLOW_MASK],
    [KEY_Z | CONSONANT_ALLOW_MASK],
    [KEY_J | CONSONANT_ALLOW_MASK],
    [KEY_F | END_CONSONANT_MASK],
    [KEY_W | END_CONSONANT_MASK],
    [KEY_J | END_CONSONANT_MASK],
]

/// End consonant table
let vnEndConsonantTable: [[UInt16]] = [
    [KEY_T], [KEY_P], [KEY_C], [KEY_N], [KEY_M],
    [KEY_G | END_CONSONANT_MASK], [KEY_K | END_CONSONANT_MASK], [KEY_H | END_CONSONANT_MASK],
    [KEY_C, KEY_H], [KEY_N, KEY_H], [KEY_N, KEY_G],
]

/// Standalone W bad list (keys that cannot follow W as standalone)
let vnStandaloneWBad: [UInt16] = [KEY_W, KEY_E, KEY_Y, KEY_F, KEY_J, KEY_K, KEY_Z]

/// Double W allowed pairs (consonant clusters that allow a standalone W after them)
let vnDoubleWAllowed: [[UInt16]] = [
    [KEY_T, KEY_R], [KEY_T, KEY_H], [KEY_C, KEY_H],
    [KEY_N, KEY_H], [KEY_N, KEY_G], [KEY_K, KEY_H],
    [KEY_G, KEY_I], [KEY_P, KEY_H], [KEY_G, KEY_H],
]

/// Quick start consonants (F→PH, J→GI, W→QU)
let vnQuickStartConsonant: [UInt16: [UInt16]] = [
    KEY_F: [KEY_P, KEY_H],
    KEY_J: [KEY_G, KEY_I],
    KEY_W: [KEY_Q, KEY_U],
]

/// Quick end consonants (G→NG, H→NH, K→CH)
let vnQuickEndConsonant: [UInt16: [UInt16]] = [
    KEY_G: [KEY_N, KEY_G],
    KEY_H: [KEY_N, KEY_H],
    KEY_K: [KEY_C, KEY_H],
]

/// Code tables: [codeTableIndex][keyCode] → array of character codes
/// Index 0=Unicode, 1=TCVN3, 2=VNI, 3=Unicode Compound, 4=CP1258
let vnCodeTable: [[UInt32: [UInt16]]] = [
    // 0: Unicode
    [
        UInt32(KEY_A):           [0x00C2,0x00E2, 0x0102,0x0103, 0x00C1,0x00E1, 0x00C0,0x00E0, 0x1EA2,0x1EA3, 0x00C3,0x00E3, 0x1EA0,0x1EA1],
        UInt32(KEY_O):           [0x00D4,0x00F4, 0x01A0,0x01A1, 0x00D3,0x00F3, 0x00D2,0x00F2, 0x1ECE,0x1ECF, 0x00D5,0x00F5, 0x1ECC,0x1ECD],
        UInt32(KEY_U):           [0x0000,0x0000, 0x01AF,0x01B0, 0x00DA,0x00FA, 0x00D9,0x00F9, 0x1EE6,0x1EE7, 0x0168,0x0169, 0x1EE4,0x1EE5],
        UInt32(KEY_E):           [0x00CA,0x00EA, 0x0000,0x0000, 0x00C9,0x00E9, 0x00C8,0x00E8, 0x1EBA,0x1EBB, 0x1EBC,0x1EBD, 0x1EB8,0x1EB9],
        UInt32(KEY_D):           [0x0110,0x0111],
        UInt32(KEY_A)|TONE_MASK: [0x1EA4,0x1EA5, 0x1EA6,0x1EA7, 0x1EA8,0x1EA9, 0x1EAA,0x1EAB, 0x1EAC,0x1EAD],
        UInt32(KEY_A)|TONEW_MASK:[0x1EAE,0x1EAF, 0x1EB0,0x1EB1, 0x1EB2,0x1EB3, 0x1EB4,0x1EB5, 0x1EB6,0x1EB7],
        UInt32(KEY_O)|TONE_MASK: [0x1ED0,0x1ED1, 0x1ED2,0x1ED3, 0x1ED4,0x1ED5, 0x1ED6,0x1ED7, 0x1ED8,0x1ED9],
        UInt32(KEY_O)|TONEW_MASK:[0x1EDA,0x1EDB, 0x1EDC,0x1EDD, 0x1EDE,0x1EDF, 0x1EE0,0x1EE1, 0x1EE2,0x1EE3],
        UInt32(KEY_U)|TONEW_MASK:[0x1EE8,0x1EE9, 0x1EEA,0x1EEB, 0x1EEC,0x1EED, 0x1EEE,0x1EEF, 0x1EF0,0x1EF1],
        UInt32(KEY_E)|TONE_MASK: [0x1EBE,0x1EBF, 0x1EC0,0x1EC1, 0x1EC2,0x1EC3, 0x1EC4,0x1EC5, 0x1EC6,0x1EC7],
        UInt32(KEY_I):           [0x00CD,0x00ED, 0x00CC,0x00EC, 0x1EC8,0x1EC9, 0x0128,0x0129, 0x1ECA,0x1ECB],
        UInt32(KEY_Y):           [0x00DD,0x00FD, 0x1EF2,0x1EF3, 0x1EF6,0x1EF7, 0x1EF8,0x1EF9, 0x1EF4,0x1EF5],
    ],
    // 1: TCVN3 (ABC)
    [
        UInt32(KEY_A):           [0xA2,0xA9, 0xA1,0xA8, 0xB8,0xB8, 0xB5,0xB5, 0xB6,0xB6, 0xB7,0xB7, 0xB9,0xB9],
        UInt32(KEY_O):           [0xA4,0xAB, 0xA5,0xAC, 0xE3,0xE3, 0xDF,0xDF, 0xE1,0xE1, 0xE2,0xE2, 0xE4,0xE4],
        UInt32(KEY_U):           [0x00,0x00, 0xA6,0xAD, 0xF3,0xF3, 0xEF,0xEF, 0xF1,0xF1, 0xF2,0xF2, 0xF4,0xF4],
        UInt32(KEY_E):           [0xA3,0xAA, 0x00,0x00, 0xD0,0xD0, 0xCC,0xCC, 0xCE,0xCE, 0xCF,0xCF, 0xD1,0xD1],
        UInt32(KEY_D):           [0xA7,0xAE],
        UInt32(KEY_A)|TONE_MASK: [0xCA,0xCA, 0xC7,0xC7, 0xC8,0xC8, 0xC9,0xC9, 0xCB,0xCB],
        UInt32(KEY_A)|TONEW_MASK:[0xBE,0xBE, 0xBB,0xBB, 0xBC,0xBC, 0xBD,0xBD, 0xC6,0xC6],
        UInt32(KEY_O)|TONE_MASK: [0xE8,0xE8, 0xE5,0xE5, 0xE6,0xE6, 0xE7,0xE7, 0xE9,0xE9],
        UInt32(KEY_O)|TONEW_MASK:[0xED,0xED, 0xEA,0xEA, 0xEB,0xEB, 0xEC,0xEC, 0xEE,0xEE],
        UInt32(KEY_U)|TONEW_MASK:[0xF8,0xF8, 0xF5,0xF5, 0xF6,0xF6, 0xF7,0xF7, 0xF9,0xF9],
        UInt32(KEY_E)|TONE_MASK: [0xD5,0xD5, 0xD2,0xD2, 0xD3,0xD3, 0xD4,0xD4, 0xD6,0xD6],
        UInt32(KEY_I):           [0xDD,0xDD, 0xD7,0xD7, 0xD8,0xD8, 0xDC,0xDC, 0xDE,0xDE],
        UInt32(KEY_Y):           [0xFD,0xFD, 0xFA,0xFA, 0xFB,0xFB, 0xFC,0xFC, 0xFE,0xFE],
    ],
    // 2: VNI Windows
    [
        UInt32(KEY_A):           [0xC241,0xE261, 0xCA41,0xEA61, 0xD941,0xF961, 0xD841,0xF861, 0xDB41,0xFB61, 0xD541,0xF561, 0xCF41,0xEF61],
        UInt32(KEY_O):           [0xC24F,0xE26F, 0x00D4,0x00F4, 0xD94F,0xF96F, 0xD84F,0xF86F, 0xDB4F,0xFB6F, 0xD54F,0xF56F, 0xCF4F,0xEF6F],
        UInt32(KEY_U):           [0x0000,0x0000, 0x00D6,0x00F6, 0xD955,0xF975, 0xD855,0xF875, 0xDB55,0xFB75, 0xD555,0xF575, 0xCF55,0xEF75],
        UInt32(KEY_E):           [0xC245,0xE265, 0x0000,0x0000, 0xD945,0xF965, 0xD845,0xF865, 0xDB45,0xFB65, 0xD545,0xF565, 0xCF45,0xEF65],
        UInt32(KEY_D):           [0x00D1,0x00F1],
        UInt32(KEY_A)|TONE_MASK: [0xC141,0xE161, 0xC041,0xE061, 0xC541,0xE561, 0xC341,0xE361, 0xC441,0xE461],
        UInt32(KEY_A)|TONEW_MASK:[0xC941,0xE961, 0xC841,0xE861, 0xDA41,0xFA61, 0xDC41,0xFC61, 0xCB41,0xEB61],
        UInt32(KEY_O)|TONE_MASK: [0xC14F,0xE16F, 0xC04F,0xE06F, 0xC54F,0xE56F, 0xC34F,0xE36F, 0xC44F,0xE46F],
        UInt32(KEY_O)|TONEW_MASK:[0xD9D4,0xF9F4, 0xD8D4,0xF8F4, 0xDBD4,0xFBF4, 0xD5D4,0xF5F4, 0xCFD4,0xEFF4],
        UInt32(KEY_U)|TONEW_MASK:[0xD9D6,0xF9F6, 0xD8D6,0xF8F6, 0xDBD6,0xFBF6, 0xD5D6,0xF5F6, 0xCFD6,0xEFF6],
        UInt32(KEY_E)|TONE_MASK: [0xC145,0xE165, 0xC045,0xE065, 0xC545,0xE565, 0xC345,0xE365, 0xC445,0xE465],
        UInt32(KEY_I):           [0x00CD,0x00ED, 0x00CC,0x00EC, 0x00C6,0x00E6, 0x00D3,0x00F3, 0x00D2,0x00F2],
        UInt32(KEY_Y):           [0xD959,0xF979, 0xD859,0xF879, 0xDB59,0xFB79, 0xD559,0xF579, 0x00CE,0x00EE],
    ],
    // 3: Unicode Compound
    [
        UInt32(KEY_A):           [0x00C2,0x00E2, 0x0102,0x0103, 0x2041,0x2061, 0x4041,0x4061, 0x6041,0x6061, 0x8041,0x8061, 0xA041,0xA061],
        UInt32(KEY_O):           [0x00D4,0x00F4, 0x01A0,0x01A1, 0x204F,0x206F, 0x404F,0x406F, 0x604F,0x606F, 0x804F,0x806F, 0xA04F,0xA06F],
        UInt32(KEY_U):           [0x0000,0x0000, 0x01AF,0x01B0, 0x2055,0x2075, 0x4055,0x4075, 0x6055,0x6075, 0x8055,0x8075, 0xA055,0xA075],
        UInt32(KEY_E):           [0x00CA,0x00EA, 0x0000,0x0000, 0x2045,0x2065, 0x4045,0x4065, 0x6045,0x6065, 0x8045,0x8065, 0xA045,0xA065],
        UInt32(KEY_D):           [0x0110,0x0111],
        UInt32(KEY_A)|TONE_MASK: [0x20C2,0x20E2, 0x40C2,0x40E2, 0x60C2,0x60E2, 0x80C2,0x80E2, 0xA0C2,0xA0E2],
        UInt32(KEY_A)|TONEW_MASK:[0x2102,0x2103, 0x4102,0x4103, 0x6102,0x6103, 0x8102,0x8103, 0xA102,0xA103],
        UInt32(KEY_O)|TONE_MASK: [0x20D4,0x20F4, 0x40D4,0x40F4, 0x60D4,0x60F4, 0x80D4,0x80F4, 0xA0D4,0xA0F4],
        UInt32(KEY_O)|TONEW_MASK:[0x21A0,0x21A1, 0x41A0,0x41A1, 0x61A0,0x61A1, 0x81A0,0x81A1, 0xA1A0,0xA1A1],
        UInt32(KEY_U)|TONEW_MASK:[0x21AF,0x21B0, 0x41AF,0x41B0, 0x61AF,0x61B0, 0x81AF,0x81B0, 0xA1AF,0xA1B0],
        UInt32(KEY_E)|TONE_MASK: [0x20CA,0x20EA, 0x40CA,0x40EA, 0x60CA,0x60EA, 0x80CA,0x80EA, 0xA0CA,0xA0EA],
        UInt32(KEY_I):           [0x2049,0x2069, 0x4049,0x4069, 0x6049,0x6069, 0x8049,0x8069, 0xA049,0xA069],
        UInt32(KEY_Y):           [0x2059,0x2079, 0x4059,0x4079, 0x6059,0x6079, 0x8059,0x8079, 0xA059,0xA079],
    ],
    // 4: Vietnamese Locale CP1258
    [
        UInt32(KEY_A):           [0x00C2,0x00E2, 0x00C3,0x00E3, 0xEC41,0xEC61, 0xCC41,0xCC61, 0xD241,0xD261, 0xDE41,0xDE61, 0xF241,0xF261],
        UInt32(KEY_O):           [0x00D4,0x00F4, 0x00D5,0x00F5, 0xEC4F,0xEC6F, 0xCC4F,0xCC6F, 0xD24F,0xD26F, 0xDE4F,0xDE6F, 0xF24F,0xF26F],
        UInt32(KEY_U):           [0x0000,0x0000, 0x00DD,0x00FD, 0xEC55,0xEC75, 0xCC55,0xCC75, 0xD255,0xD275, 0xDE55,0xDE75, 0xF255,0xF275],
        UInt32(KEY_E):           [0x00CA,0x00EA, 0x0000,0x0000, 0xEC45,0xEC65, 0xCC45,0xCC65, 0xD245,0xD265, 0xDE45,0xDE65, 0xF245,0xF265],
        UInt32(KEY_D):           [0x00D0,0x00F0],
        UInt32(KEY_A)|TONE_MASK: [0xECC2,0xECE2, 0xCCC2,0xCCE2, 0xD2C2,0xD2E2, 0xDEC2,0xDEE2, 0xF2C2,0xF2E2],
        UInt32(KEY_A)|TONEW_MASK:[0xECC3,0xECE3, 0xCCC3,0xCCE3, 0xD2C3,0xD2E3, 0xDEC3,0xDEE3, 0xF2C3,0xF2E3],
        UInt32(KEY_O)|TONE_MASK: [0xECD4,0xECF4, 0xCCD4,0xCCF4, 0xD2D4,0xD2F4, 0xDED4,0xDEF4, 0xF2D4,0xF2F4],
        UInt32(KEY_O)|TONEW_MASK:[0xECD5,0xECF5, 0xCCD5,0xCCF5, 0xD2D5,0xD2F5, 0xDED5,0xDEF5, 0xF2D5,0xF2F5],
        UInt32(KEY_U)|TONEW_MASK:[0xECDD,0xECFD, 0xCCDD,0xCCFD, 0xD2DD,0xD2FD, 0xDEDD,0xDEFD, 0xF2DD,0xF2FD],
        UInt32(KEY_E)|TONE_MASK: [0xECCA,0xECEA, 0xCCCA,0xCCEA, 0xD2CA,0xD2EA, 0xDECA,0xDEEA, 0xF2CA,0xF2EA],
        UInt32(KEY_I):           [0xEC49,0xEC69, 0xCC49,0xCC69, 0xD249,0xD269, 0xDE49,0xDE69, 0xF249,0xF269],
        UInt32(KEY_Y):           [0xEC59,0xEC79, 0xCC59,0xCC79, 0xD259,0xD279, 0xDE59,0xDE79, 0xF259,0xF279],
    ],
]

/// Unicode compound mark codes (sắc, huyền, hỏi, ngã, nặng)
let vnUnicodeCompoundMark: [UInt16] = [0x0301, 0x0300, 0x0309, 0x0303, 0x0323]

/// Quick Telex expansions
let vnQuickTelex: [UInt32: [UInt16]] = [
    UInt32(KEY_C): [KEY_C, KEY_H],
    UInt32(KEY_G): [KEY_G, KEY_I],
    UInt32(KEY_K): [KEY_K, KEY_H],
    UInt32(KEY_N): [KEY_N, KEY_G],
    UInt32(KEY_Q): [KEY_Q, KEY_U],
    UInt32(KEY_P): [KEY_P, KEY_H],
    UInt32(KEY_T): [KEY_T, KEY_H],
    UInt32(KEY_U): [KEY_U, KEY_U],
]

/// Character → engine key code map
let vnCharacterMap: [UInt32: UInt32] = {
    var m: [UInt32: UInt32] = [:]
    let pairs: [(UInt8, UInt16)] = [
        (UInt8(ascii: "a"), KEY_A), (UInt8(ascii: "b"), KEY_B), (UInt8(ascii: "c"), KEY_C),
        (UInt8(ascii: "d"), KEY_D), (UInt8(ascii: "e"), KEY_E), (UInt8(ascii: "f"), KEY_F),
        (UInt8(ascii: "g"), KEY_G), (UInt8(ascii: "h"), KEY_H), (UInt8(ascii: "i"), KEY_I),
        (UInt8(ascii: "j"), KEY_J), (UInt8(ascii: "k"), KEY_K), (UInt8(ascii: "l"), KEY_L),
        (UInt8(ascii: "m"), KEY_M), (UInt8(ascii: "n"), KEY_N), (UInt8(ascii: "o"), KEY_O),
        (UInt8(ascii: "p"), KEY_P), (UInt8(ascii: "q"), KEY_Q), (UInt8(ascii: "r"), KEY_R),
        (UInt8(ascii: "s"), KEY_S), (UInt8(ascii: "t"), KEY_T), (UInt8(ascii: "u"), KEY_U),
        (UInt8(ascii: "v"), KEY_V), (UInt8(ascii: "w"), KEY_W), (UInt8(ascii: "x"), KEY_X),
        (UInt8(ascii: "y"), KEY_Y), (UInt8(ascii: "z"), KEY_Z),
    ]
    for (ch, kc) in pairs {
        m[UInt32(ch)] = UInt32(kc)
        let upper = ch - 32 // uppercase offset
        m[UInt32(upper)] = UInt32(kc) | CAPS_MASK
    }
    let numPairs: [(UInt8, UInt16, UInt8)] = [
        (UInt8(ascii: "1"), KEY_1, UInt8(ascii: "!")),
        (UInt8(ascii: "2"), KEY_2, UInt8(ascii: "@")),
        (UInt8(ascii: "3"), KEY_3, UInt8(ascii: "#")),
        (UInt8(ascii: "4"), KEY_4, UInt8(ascii: "$")),
        (UInt8(ascii: "5"), KEY_5, UInt8(ascii: "%")),
        (UInt8(ascii: "6"), KEY_6, UInt8(ascii: "^")),
        (UInt8(ascii: "7"), KEY_7, UInt8(ascii: "&")),
        (UInt8(ascii: "8"), KEY_8, UInt8(ascii: "*")),
        (UInt8(ascii: "9"), KEY_9, UInt8(ascii: "(")),
        (UInt8(ascii: "0"), KEY_0, UInt8(ascii: ")")),
    ]
    for (lc, kc, uc) in numPairs {
        m[UInt32(lc)] = UInt32(kc)
        m[UInt32(uc)] = UInt32(kc) | CAPS_MASK
    }
    let symPairs: [(UInt8, UInt16, UInt8)] = [
        (UInt8(ascii: "`"),  KEY_BACKQUOTE,     UInt8(ascii: "~")),
        (UInt8(ascii: "-"),  KEY_MINUS,          UInt8(ascii: "_")),
        (UInt8(ascii: "="),  KEY_EQUALS,         UInt8(ascii: "+")),
        (UInt8(ascii: "["),  KEY_LEFT_BRACKET,   UInt8(ascii: "{")),
        (UInt8(ascii: "]"),  KEY_RIGHT_BRACKET,  UInt8(ascii: "}")),
        (UInt8(ascii: ";"),  KEY_SEMICOLON,      UInt8(ascii: ":")),
        (UInt8(ascii: "'"),  KEY_QUOTE,          UInt8(ascii: "\"")),
        (UInt8(ascii: ","),  KEY_COMMA,          UInt8(ascii: "<")),
        (UInt8(ascii: "."),  KEY_DOT,            UInt8(ascii: ">")),
        (UInt8(ascii: "/"),  KEY_SLASH,          UInt8(ascii: "?")),
    ]
    for (lc, kc, uc) in symPairs {
        m[UInt32(lc)] = UInt32(kc)
        m[UInt32(uc)] = UInt32(kc) | CAPS_MASK
    }
    // Backslash and pipe
    m[UInt32(UInt8(ascii: "\\"))] = UInt32(KEY_BACK_SLASH)
    m[UInt32(UInt8(ascii: "|"))]  = UInt32(KEY_BACK_SLASH) | CAPS_MASK
    // Space
    m[UInt32(UInt8(ascii: " "))]  = UInt32(KEY_SPACE)
    return m
}()

/// Reverse map: engine key code → ASCII character
let vnKeyCodeToChar: [UInt32: UInt32] = {
    var m: [UInt32: UInt32] = [:]
    for (ch, kc) in vnCharacterMap { m[kc] = ch }
    return m
}()

/// Look up ASCII character for a given engine key code
func vnKeyCodeToCharacter(_ keyCode: UInt32) -> UInt16 {
    guard let ch = vnKeyCodeToChar[keyCode] else { return 0 }
    return UInt16(ch)
}
