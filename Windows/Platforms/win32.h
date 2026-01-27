//
//  win32.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTV_WIN32_H
#define PHTV_WIN32_H

#ifdef _WIN32
#include <windows.h>
#else
// Fallback definitions if not compiling on Windows environment immediately
#define VK_ESCAPE         0x1B
#define VK_DELETE         0x2E
#define VK_TAB            0x09
#define VK_RETURN         0x0D
#define VK_SPACE          0x20
#define VK_LEFT           0x25
#define VK_UP             0x26
#define VK_RIGHT          0x27
#define VK_DOWN           0x28
#define VK_LSHIFT         0xA0
#define VK_RSHIFT         0xA1
#define VK_LCONTROL       0xA2
#define VK_RCONTROL       0xA3
#define VK_LMENU          0xA4
#define VK_RMENU          0xA5
#define VK_LWIN           0x5B
#define VK_RWIN           0x5C
#endif

// Map PHTV generic keys to Windows Virtual Key Codes
#define KEY_ESC         VK_ESCAPE
#define KEY_DELETE      VK_DELETE
#define KEY_TAB         VK_TAB
#define KEY_ENTER       VK_RETURN
#define KEY_RETURN      VK_RETURN
#define KEY_SPACE       VK_SPACE
#define KEY_LEFT        VK_LEFT
#define KEY_RIGHT       VK_RIGHT
#define KEY_DOWN        VK_DOWN
#define KEY_UP          VK_UP

// A-Z
#define KEY_A           'A'
#define KEY_B           'B'
#define KEY_C           'C'
#define KEY_D           'D'
#define KEY_E           'E'
#define KEY_F           'F'
#define KEY_G           'G'
#define KEY_H           'H'
#define KEY_I           'I'
#define KEY_J           'J'
#define KEY_K           'K'
#define KEY_L           'L'
#define KEY_M           'M'
#define KEY_N           'N'
#define KEY_O           'O'
#define KEY_P           'P'
#define KEY_Q           'Q'
#define KEY_R           'R'
#define KEY_S           'S'
#define KEY_T           'T'
#define KEY_U           'U'
#define KEY_V           'V'
#define KEY_W           'W'
#define KEY_X           'X'
#define KEY_Y           'Y'
#define KEY_Z           'Z'

// 0-9
#define KEY_1           '1'
#define KEY_2           '2'
#define KEY_3           '3'
#define KEY_4           '4'
#define KEY_5           '5'
#define KEY_6           '6'
#define KEY_7           '7'
#define KEY_8           '8'
#define KEY_9           '9'
#define KEY_0           '0'

// Special keys
#define KEY_LEFT_BRACKET  0xDB  // VK_OEM_4  [{
#define KEY_RIGHT_BRACKET 0xDD  // VK_OEM_6  ]}
#define KEY_BACK_SLASH    0xDC  // VK_OEM_5  \|
#define KEY_SEMICOLON     0xBA  // VK_OEM_1  ;:
#define KEY_QUOTE         0xDE  // VK_OEM_7  '"
#define KEY_COMMA         0xBC  // VK_OEM_COMMA ,<
#define KEY_DOT           0xBE  // VK_OEM_PERIOD .>
#define KEY_SLASH         0xBF  // VK_OEM_2  /?
#define KEY_BACKQUOTE     0xC0  // VK_OEM_3  `~
#define KEY_MINUS         0xBD  // VK_OEM_MINUS -_
#define KEY_EQUALS        0xBB  // VK_OEM_PLUS =+

// Modifiers
#define KEY_LEFT_SHIFT    VK_LSHIFT
#define KEY_RIGHT_SHIFT   VK_RSHIFT
#define KEY_LEFT_CONTROL  VK_LCONTROL
#define KEY_RIGHT_CONTROL VK_RCONTROL
#define KEY_LEFT_OPTION   VK_LMENU
#define KEY_RIGHT_OPTION  VK_RMENU
#define KEY_LEFT_COMMAND  VK_LWIN
#define KEY_RIGHT_COMMAND VK_RWIN

#endif // PHTV_WIN32_H
