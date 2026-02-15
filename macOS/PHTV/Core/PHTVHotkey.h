//
//  PHTVHotkey.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTVHotkey_h
#define PHTVHotkey_h

#include <stdint.h>

// Hotkey data layout:
// - bits 0..7: key code (0xFE means modifier-only hotkey)
// - bit 8: Control
// - bit 9: Option
// - bit 10: Command
// - bit 11: Shift
// - bit 12: Fn
// - bit 15: Beep
#define HOTKEY_KEY_MASK                         0x00FF
#define HOTKEY_CONTROL_MASK                     0x0100
#define HOTKEY_OPTION_MASK                      0x0200
#define HOTKEY_COMMAND_MASK                     0x0400
#define HOTKEY_SHIFT_MASK                       0x0800
#define HOTKEY_FN_MASK                          0x1000
#define HOTKEY_BEEP_MASK                        0x8000

#define HOTKEY_NO_KEY                           0x00FE
#define EMPTY_HOTKEY                            0xFE0000FE
#define PHTV_DEFAULT_SWITCH_HOTKEY_STATUS       (HOTKEY_CONTROL_MASK | HOTKEY_SHIFT_MASK | HOTKEY_NO_KEY)

enum {
    PHTV_HOTKEY_CONTROL_BIT_SHIFT = 8,
    PHTV_HOTKEY_OPTION_BIT_SHIFT = 9,
    PHTV_HOTKEY_COMMAND_BIT_SHIFT = 10,
    PHTV_HOTKEY_SHIFT_BIT_SHIFT = 11,
    PHTV_HOTKEY_FN_BIT_SHIFT = 12,
    PHTV_HOTKEY_BEEP_BIT_SHIFT = 15
};

static inline int phtv_hotkey_bool(const uint64_t data) {
    return data ? 1 : 0;
}

static inline int phtv_hotkey_get_switch_key(const int data) {
    return data & HOTKEY_KEY_MASK;
}

static inline int phtv_hotkey_has_key(const int data) {
    return phtv_hotkey_get_switch_key(data) != HOTKEY_NO_KEY;
}

static inline int phtv_hotkey_key_matches(const int data, const int keyCode) {
    return phtv_hotkey_get_switch_key(data) == (keyCode & HOTKEY_KEY_MASK);
}

static inline int phtv_hotkey_raw_key_has_key(const int keyCode) {
    return (keyCode & HOTKEY_KEY_MASK) != HOTKEY_NO_KEY;
}

static inline int phtv_hotkey_has_control(const int data) {
    return (data & HOTKEY_CONTROL_MASK) ? 1 : 0;
}

static inline int phtv_hotkey_has_option(const int data) {
    return (data & HOTKEY_OPTION_MASK) ? 1 : 0;
}

static inline int phtv_hotkey_has_command(const int data) {
    return (data & HOTKEY_COMMAND_MASK) ? 1 : 0;
}

static inline int phtv_hotkey_has_shift(const int data) {
    return (data & HOTKEY_SHIFT_MASK) ? 1 : 0;
}

static inline int phtv_hotkey_has_fn(const int data) {
    return (data & HOTKEY_FN_MASK) ? 1 : 0;
}

static inline int phtv_hotkey_has_beep(const int data) {
    return (data & HOTKEY_BEEP_MASK) ? 1 : 0;
}

static inline int phtv_hotkey_without_beep(const int data) {
    return data & (~HOTKEY_BEEP_MASK);
}

static inline int phtv_hotkey_is_empty(const int data) {
    return phtv_hotkey_without_beep(data) == EMPTY_HOTKEY;
}

static inline int phtv_hotkey_default_switch_status(void) {
    return PHTV_DEFAULT_SWITCH_HOTKEY_STATUS;
}

static inline int phtv_hotkey_matches_flags(const int data,
                                            const uint64_t flags,
                                            const uint64_t controlMask,
                                            const uint64_t optionMask,
                                            const uint64_t commandMask,
                                            const uint64_t shiftMask,
                                            const uint64_t fnMask) {
    if (phtv_hotkey_has_control(data) ^ phtv_hotkey_bool(flags & controlMask)) {
        return 0;
    }
    if (phtv_hotkey_has_option(data) ^ phtv_hotkey_bool(flags & optionMask)) {
        return 0;
    }
    if (phtv_hotkey_has_command(data) ^ phtv_hotkey_bool(flags & commandMask)) {
        return 0;
    }
    if (phtv_hotkey_has_shift(data) ^ phtv_hotkey_bool(flags & shiftMask)) {
        return 0;
    }
    if (phtv_hotkey_has_fn(data) ^ phtv_hotkey_bool(flags & fnMask)) {
        return 0;
    }
    return 1;
}

static inline int phtv_hotkey_modifiers_held(const int data,
                                             const uint64_t flags,
                                             const uint64_t controlMask,
                                             const uint64_t optionMask,
                                             const uint64_t commandMask,
                                             const uint64_t shiftMask,
                                             const uint64_t fnMask) {
    if (phtv_hotkey_has_control(data) && !(flags & controlMask)) {
        return 0;
    }
    if (phtv_hotkey_has_option(data) && !(flags & optionMask)) {
        return 0;
    }
    if (phtv_hotkey_has_command(data) && !(flags & commandMask)) {
        return 0;
    }
    if (phtv_hotkey_has_shift(data) && !(flags & shiftMask)) {
        return 0;
    }
    if (phtv_hotkey_has_fn(data) && !(flags & fnMask)) {
        return 0;
    }
    return 1;
}

static inline int phtv_hotkey_set_masked_bit(const int data,
                                             const int mask,
                                             const int bitShift,
                                             const int value) {
    return (data & (~mask)) | (phtv_hotkey_bool(value) << bitShift);
}

static inline int phtv_hotkey_with_switch_key(const int data, const int key) {
    return (data & (~HOTKEY_KEY_MASK)) | (key & HOTKEY_KEY_MASK);
}

static inline int phtv_hotkey_with_control(const int data, const int value) {
    return phtv_hotkey_set_masked_bit(data, HOTKEY_CONTROL_MASK, PHTV_HOTKEY_CONTROL_BIT_SHIFT, value);
}

static inline int phtv_hotkey_with_option(const int data, const int value) {
    return phtv_hotkey_set_masked_bit(data, HOTKEY_OPTION_MASK, PHTV_HOTKEY_OPTION_BIT_SHIFT, value);
}

static inline int phtv_hotkey_with_command(const int data, const int value) {
    return phtv_hotkey_set_masked_bit(data, HOTKEY_COMMAND_MASK, PHTV_HOTKEY_COMMAND_BIT_SHIFT, value);
}

static inline int phtv_hotkey_with_shift(const int data, const int value) {
    return phtv_hotkey_set_masked_bit(data, HOTKEY_SHIFT_MASK, PHTV_HOTKEY_SHIFT_BIT_SHIFT, value);
}

static inline int phtv_hotkey_with_fn(const int data, const int value) {
    return phtv_hotkey_set_masked_bit(data, HOTKEY_FN_MASK, PHTV_HOTKEY_FN_BIT_SHIFT, value);
}

static inline int phtv_hotkey_with_beep(const int data, const int value) {
    return phtv_hotkey_set_masked_bit(data, HOTKEY_BEEP_MASK, PHTV_HOTKEY_BEEP_BIT_SHIFT, value);
}

// Compatibility macros kept for existing call sites.
#define GET_BOOL(data)                          phtv_hotkey_bool((data))
#define GET_SWITCH_KEY(data)                    phtv_hotkey_get_switch_key((data))
#define HOTKEY_HAS_KEY(data)                    phtv_hotkey_has_key((data))
#define HOTKEY_KEY_MATCHES(data, keyCode)       phtv_hotkey_key_matches((data), (keyCode))
#define HOTKEY_RAW_KEY_HAS_KEY(keyCode)         phtv_hotkey_raw_key_has_key((keyCode))
#define HOTKEY_MATCHES_FLAGS(data, flags, controlMask, optionMask, commandMask, shiftMask, fnMask) \
                                                phtv_hotkey_matches_flags((data), (flags), (controlMask), (optionMask), (commandMask), (shiftMask), (fnMask))
#define HOTKEY_MODIFIERS_HELD(data, flags, controlMask, optionMask, commandMask, shiftMask, fnMask) \
                                                phtv_hotkey_modifiers_held((data), (flags), (controlMask), (optionMask), (commandMask), (shiftMask), (fnMask))

#define HAS_CONTROL(data)                       phtv_hotkey_has_control((data))
#define HAS_OPTION(data)                        phtv_hotkey_has_option((data))
#define HAS_COMMAND(data)                       phtv_hotkey_has_command((data))
#define HAS_SHIFT(data)                         phtv_hotkey_has_shift((data))
#define HAS_FN(data)                            phtv_hotkey_has_fn((data))
#define HAS_BEEP(data)                          phtv_hotkey_has_beep((data))

#define HOTKEY_WITHOUT_BEEP(data)               phtv_hotkey_without_beep((data))
#define IS_EMPTY_HOTKEY(data)                   phtv_hotkey_is_empty((data))
#define DEFAULT_SWITCH_HOTKEY_STATUS            phtv_hotkey_default_switch_status()

#define SET_SWITCH_KEY(data, key)               ((data) = phtv_hotkey_with_switch_key((data), (key)))
#define SET_CONTROL_KEY(data, val)              ((data) = phtv_hotkey_with_control((data), (val)))
#define SET_OPTION_KEY(data, val)               ((data) = phtv_hotkey_with_option((data), (val)))
#define SET_COMMAND_KEY(data, val)              ((data) = phtv_hotkey_with_command((data), (val)))
#define SET_SHIFT_KEY(data, val)                ((data) = phtv_hotkey_with_shift((data), (val)))
#define SET_FN_KEY(data, val)                   ((data) = phtv_hotkey_with_fn((data), (val)))
#define SET_BEEP_KEY(data, val)                 ((data) = phtv_hotkey_with_beep((data), (val)))

#endif /* PHTVHotkey_h */
