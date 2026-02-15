//
//  phtv_mac_keys.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//


#ifndef PHTV_MAC_KEYS_H
#define PHTV_MAC_KEYS_H

// Compatibility define for older code that checked this symbol directly.
#ifndef PHTV_MAC_H
#define PHTV_MAC_H
#endif

// Mac virtual key codes used throughout the engine/app.
// Using enum constants avoids macro pollution while keeping legacy names intact.
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

#endif // PHTV_MAC_KEYS_H
