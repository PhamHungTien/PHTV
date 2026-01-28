//
//  linux.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTV_LINUX_H
#define PHTV_LINUX_H

#include <linux/input-event-codes.h>

// Map PHTV generic keys to Linux Input Event Codes

// Control keys
#ifndef KEY_ESC
#define KEY_ESC         1
#endif

#ifndef KEY_DELETE
#define KEY_DELETE      111
#endif

#ifndef KEY_TAB
#define KEY_TAB         15
#endif

#ifndef KEY_ENTER
#define KEY_ENTER       28
#endif

#define KEY_RETURN      KEY_ENTER

#ifndef KEY_SPACE
#define KEY_SPACE       57
#endif

#ifndef KEY_LEFT
#define KEY_LEFT        105
#endif

#ifndef KEY_RIGHT
#define KEY_RIGHT       106
#endif

#ifndef KEY_UP
#define KEY_UP          103
#endif

#ifndef KEY_DOWN
#define KEY_DOWN        108
#endif

// A-Z (Linux defines KEY_A...KEY_Z)
// We rely on standard linux/input.h or input-event-codes.h definitions
// but we define mappings for consistency if needed. 
// However, the PHTV engine uses KEY_A, KEY_B... 
// linux/input.h defines these.

// 0-9
// Defined in linux/input.h as KEY_1, KEY_2...

// Special keys
#define KEY_LEFT_BRACKET    KEY_LEFTBRACE
#define KEY_RIGHT_BRACKET   KEY_RIGHTBRACE
#define KEY_BACK_SLASH      KEY_BACKSLASH
#define KEY_SEMICOLON       KEY_SEMICOLON
#define KEY_QUOTE           KEY_APOSTROPHE
#define KEY_COMMA           KEY_COMMA
#define KEY_DOT             KEY_DOT
#define KEY_SLASH           KEY_SLASH
#define KEY_BACKQUOTE       KEY_GRAVE
#define KEY_MINUS           KEY_MINUS
#define KEY_EQUALS          KEY_EQUAL

// Modifiers
#define KEY_LEFT_SHIFT      KEY_LEFTSHIFT
#define KEY_RIGHT_SHIFT     KEY_RIGHTSHIFT
#define KEY_LEFT_CONTROL    KEY_LEFTCTRL
#define KEY_RIGHT_CONTROL   KEY_RIGHTCTRL
#define KEY_LEFT_OPTION     KEY_LEFTALT
#define KEY_RIGHT_OPTION    KEY_RIGHTALT
#define KEY_LEFT_COMMAND    KEY_LEFTMETA
#define KEY_RIGHT_COMMAND   KEY_RIGHTMETA

#endif // PHTV_LINUX_H
