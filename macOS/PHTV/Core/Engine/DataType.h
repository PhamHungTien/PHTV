//
//  DataType.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef DataType_h
#define DataType_h

#include <vector>

//#define V_PLATFORM_MAC              1
//#define V_PLATFORM_WINDOWS          2

#define MAX_BUFF 32

enum vKeyEvent {
    Keyboard,
    Mouse
};

enum vKeyEventState {
    KeyDown,
    KeyUp,
    MouseDown,
    MouseUp
};

enum vKeyInputType {
    vTelex = 0,
    vVNI,
    vSimpleTelex1,
    vSimpleTelex2
};

typedef unsigned char Byte;
typedef signed char Int8;
typedef unsigned char Uint8;
typedef unsigned short Uint16;
typedef unsigned int Uint32;
typedef unsigned long int Uint64;

enum HoolCodeState {
    vDoNothing = 0, //do not do anything
    vWillProcess, //will reverse
    vBreakWord, //start new
    vRestore, //restore character to old char
    vReplaceMaro, //replace by macro
    vRestoreAndStartNewSession, //special flag: use for restore key if invalid word with break character (, . ")
};

//bytes data for main program
struct vKeyHookState {
    /*
     * 0: Do nothing
     * 1: Process
     * 2: Word break;
     * 3: Restore
     * 4: replace by macro
     */
    Byte code;
    Byte backspaceCount;
    Byte newCharCount;
    
    /**
     * 1: Word Break
     * 2: Delete key
     * 3: Normal key
     * 4: Should not send empty character
     * 5: Auto English restore (to distinguish from Text Replacement)
     */
    Byte extCode;
    
    Uint32 charData[MAX_BUFF]; //new character will be put in queue
    
    std::vector<Uint32> macroKey; //used for macro function; it is a key
    std::vector<Uint32> macroData; //used for macro function; it is keycode data
};

// Compatibility define for older code that checked this symbol directly.
#ifndef PHTV_MAC_H
#define PHTV_MAC_H
#endif

// Mac virtual key codes used throughout the engine/app.
typedef enum PHTVMacKeyCode {
    KEY_ESC = 53,
    KEY_DELETE = 51,
    KEY_TAB = 48,
    KEY_ENTER = 76,
    KEY_RETURN = 36,
    KEY_SPACE = 49,
    KEY_LEFT = 123,
    KEY_RIGHT = 124,
    KEY_DOWN = 125,
    KEY_UP = 126,
    KEY_HOME = 115,
    KEY_PAGE_UP = 116,
    KEY_FORWARD_DELETE = 117,
    KEY_END = 119,
    KEY_PAGE_DOWN = 121,

    KEY_EMPTY = 256,
    KEY_A = 0,
    KEY_B = 11,
    KEY_C = 8,
    KEY_D = 2,
    KEY_E = 14,
    KEY_F = 3,
    KEY_G = 5,
    KEY_H = 4,
    KEY_I = 34,
    KEY_J = 38,
    KEY_K = 40,
    KEY_L = 37,
    KEY_M = 46,
    KEY_N = 45,
    KEY_O = 31,
    KEY_P = 35,
    KEY_Q = 12,
    KEY_R = 15,
    KEY_S = 1,
    KEY_T = 17,
    KEY_U = 32,
    KEY_V = 9,
    KEY_W = 13,
    KEY_X = 7,
    KEY_Y = 16,
    KEY_Z = 6,

    KEY_1 = 18,
    KEY_2 = 19,
    KEY_3 = 20,
    KEY_4 = 21,
    KEY_5 = 23,
    KEY_6 = 22,
    KEY_7 = 26,
    KEY_8 = 28,
    KEY_9 = 25,
    KEY_0 = 29,

    KEY_LEFT_BRACKET = 33,
    KEY_RIGHT_BRACKET = 30,

    KEY_LEFT_SHIFT = 57,
    KEY_RIGHT_SHIFT = 60,
    KEY_DOT = 47,

    KEY_BACKQUOTE = 50,
    KEY_MINUS = 27,
    KEY_EQUALS = 24,
    KEY_BACK_SLASH = 42,
    KEY_SEMICOLON = 41,
    KEY_QUOTE = 39,
    KEY_COMMA = 43,
    KEY_SLASH = 44,

    // Modifier keys (for restore key feature)
    KEY_LEFT_COMMAND = 55,
    KEY_RIGHT_COMMAND = 54,
    KEY_LEFT_CONTROL = 59,
    KEY_RIGHT_CONTROL = 62,
    KEY_LEFT_OPTION = 58,
    KEY_RIGHT_OPTION = 61,
    KEY_FUNCTION = 63
} PHTVMacKeyCode;

static inline int phtv_mac_key_is_arrow(const int keyCode) {
    return keyCode == KEY_LEFT || keyCode == KEY_RIGHT ||
           keyCode == KEY_UP || keyCode == KEY_DOWN;
}

static inline int phtv_mac_key_is_navigation(const int keyCode) {
    return phtv_mac_key_is_arrow(keyCode) ||
           keyCode == KEY_HOME ||
           keyCode == KEY_END ||
           keyCode == KEY_PAGE_UP ||
           keyCode == KEY_PAGE_DOWN;
}

static inline int phtv_mac_key_is_modifier(const int keyCode) {
    return keyCode == KEY_LEFT_SHIFT ||
           keyCode == KEY_RIGHT_SHIFT ||
           keyCode == KEY_LEFT_COMMAND ||
           keyCode == KEY_RIGHT_COMMAND ||
           keyCode == KEY_LEFT_CONTROL ||
           keyCode == KEY_RIGHT_CONTROL ||
           keyCode == KEY_LEFT_OPTION ||
           keyCode == KEY_RIGHT_OPTION ||
           keyCode == KEY_FUNCTION;
}

//internal engine data
#define CAPS_MASK                               0x10000
#define TONE_MASK                               0x20000
#define TONEW_MASK                              0x40000

/*
 * MARK MASK
 * 1: Dấu Sắc - á
 * 2: Dấu Huyền - à
 * 3: Dấu Hỏi - ả
 * 4: Dấu Ngã - ã
 * 5: dấu Nặng - ạ
 */
#define MARK1_MASK                              0x80000
#define MARK2_MASK                              0x100000
#define MARK3_MASK                              0x200000
#define MARK4_MASK                              0x400000
#define MARK5_MASK                              0x800000

//for checking has mark or not
#define MARK_MASK                               0xF80000

//mark and get first 16 bytes character
#define CHAR_MASK                               0xFFFF

//Check whether the data is create by standalone key or not (W)
#define STANDALONE_MASK                         0x1000000

//Chec whether the data is keyboard code or character code
#define CHAR_CODE_MASK                          0x2000000

#define PURE_CHARACTER_MASK                     0x80000000

//for special feature
#define END_CONSONANT_MASK                      0x4000
#define CONSONANT_ALLOW_MASK                    0x8000


//Utilities macro
#define IS_CONSONANT(keyCode) !(keyCode == KEY_A || keyCode == KEY_E || keyCode == KEY_U || keyCode == KEY_Y || keyCode == KEY_I || keyCode == KEY_O)
//#define IS_MARK_KEY(keyCode) (keyCode == KEY_S || keyCode == KEY_F || keyCode == KEY_R || keyCode == KEY_J || keyCode == KEY_X)
#define CHR(index) (Uint16)TypingWord[index]

//is VNI or Unicode compound...
#define IS_DOUBLE_CODE(code) (code == 2 || code == 3)
#define IS_VNI_CODE(code) (code == 2)
#define IS_QUICK_TELEX_KEY(code) (_index > 0 && (code == KEY_C || code == KEY_G || code == KEY_K || code == KEY_N || code == KEY_Q || code == KEY_P || code == KEY_T) && \
                                    (Uint16)TypingWord[_index-1] == code)

#define IS_NUMBER_KEY(code) (code == KEY_1 || code == KEY_2 || code == KEY_3 || code == KEY_4 || code == KEY_5 || code == KEY_6 || code == KEY_7 || code == KEY_8 || code == KEY_9 || code == KEY_0)

#endif /* DataType_h */
