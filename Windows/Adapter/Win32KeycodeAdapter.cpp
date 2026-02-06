#include "Win32KeycodeAdapter.h"

namespace phtv::windows_adapter {

bool mapVirtualKeyToEngine(std::uint32_t virtualKey, Uint16& outEngineKey) {
    switch (virtualKey) {
        case 0x1B: outEngineKey = KEY_ESC; return true;      // VK_ESCAPE
        case 0x08: outEngineKey = KEY_DELETE; return true;   // VK_BACK
        case 0x09: outEngineKey = KEY_TAB; return true;      // VK_TAB
        case 0x0D: outEngineKey = KEY_RETURN; return true;   // VK_RETURN
        case 0x20: outEngineKey = KEY_SPACE; return true;    // VK_SPACE
        case 0x25: outEngineKey = KEY_LEFT; return true;     // VK_LEFT
        case 0x26: outEngineKey = KEY_UP; return true;       // VK_UP
        case 0x27: outEngineKey = KEY_RIGHT; return true;    // VK_RIGHT
        case 0x28: outEngineKey = KEY_DOWN; return true;     // VK_DOWN

        case 'A': outEngineKey = KEY_A; return true;
        case 'B': outEngineKey = KEY_B; return true;
        case 'C': outEngineKey = KEY_C; return true;
        case 'D': outEngineKey = KEY_D; return true;
        case 'E': outEngineKey = KEY_E; return true;
        case 'F': outEngineKey = KEY_F; return true;
        case 'G': outEngineKey = KEY_G; return true;
        case 'H': outEngineKey = KEY_H; return true;
        case 'I': outEngineKey = KEY_I; return true;
        case 'J': outEngineKey = KEY_J; return true;
        case 'K': outEngineKey = KEY_K; return true;
        case 'L': outEngineKey = KEY_L; return true;
        case 'M': outEngineKey = KEY_M; return true;
        case 'N': outEngineKey = KEY_N; return true;
        case 'O': outEngineKey = KEY_O; return true;
        case 'P': outEngineKey = KEY_P; return true;
        case 'Q': outEngineKey = KEY_Q; return true;
        case 'R': outEngineKey = KEY_R; return true;
        case 'S': outEngineKey = KEY_S; return true;
        case 'T': outEngineKey = KEY_T; return true;
        case 'U': outEngineKey = KEY_U; return true;
        case 'V': outEngineKey = KEY_V; return true;
        case 'W': outEngineKey = KEY_W; return true;
        case 'X': outEngineKey = KEY_X; return true;
        case 'Y': outEngineKey = KEY_Y; return true;
        case 'Z': outEngineKey = KEY_Z; return true;

        case '0': outEngineKey = KEY_0; return true;
        case '1': outEngineKey = KEY_1; return true;
        case '2': outEngineKey = KEY_2; return true;
        case '3': outEngineKey = KEY_3; return true;
        case '4': outEngineKey = KEY_4; return true;
        case '5': outEngineKey = KEY_5; return true;
        case '6': outEngineKey = KEY_6; return true;
        case '7': outEngineKey = KEY_7; return true;
        case '8': outEngineKey = KEY_8; return true;
        case '9': outEngineKey = KEY_9; return true;

        // OEM punctuation keys (US layout virtual keys)
        case 0xBA: outEngineKey = KEY_SEMICOLON; return true;      // VK_OEM_1
        case 0xBB: outEngineKey = KEY_EQUALS; return true;         // VK_OEM_PLUS
        case 0xBC: outEngineKey = KEY_COMMA; return true;          // VK_OEM_COMMA
        case 0xBD: outEngineKey = KEY_MINUS; return true;          // VK_OEM_MINUS
        case 0xBE: outEngineKey = KEY_DOT; return true;            // VK_OEM_PERIOD
        case 0xBF: outEngineKey = KEY_SLASH; return true;          // VK_OEM_2
        case 0xC0: outEngineKey = KEY_BACKQUOTE; return true;      // VK_OEM_3
        case 0xDB: outEngineKey = KEY_LEFT_BRACKET; return true;   // VK_OEM_4
        case 0xDC: outEngineKey = KEY_BACK_SLASH; return true;     // VK_OEM_5
        case 0xDD: outEngineKey = KEY_RIGHT_BRACKET; return true;  // VK_OEM_6
        case 0xDE: outEngineKey = KEY_QUOTE; return true;          // VK_OEM_7

        default:
            return false;
    }
}

bool mapEngineKeyToVirtualKey(Uint16 engineKey, std::uint16_t& outVirtualKey) {
    switch (engineKey) {
        case KEY_ESC: outVirtualKey = 0x1B; return true;      // VK_ESCAPE
        case KEY_DELETE: outVirtualKey = 0x08; return true;   // VK_BACK
        case KEY_TAB: outVirtualKey = 0x09; return true;      // VK_TAB
        case KEY_ENTER:
        case KEY_RETURN: outVirtualKey = 0x0D; return true;   // VK_RETURN
        case KEY_SPACE: outVirtualKey = 0x20; return true;    // VK_SPACE
        case KEY_LEFT: outVirtualKey = 0x25; return true;     // VK_LEFT
        case KEY_UP: outVirtualKey = 0x26; return true;       // VK_UP
        case KEY_RIGHT: outVirtualKey = 0x27; return true;    // VK_RIGHT
        case KEY_DOWN: outVirtualKey = 0x28; return true;     // VK_DOWN

        case KEY_A: outVirtualKey = 'A'; return true;
        case KEY_B: outVirtualKey = 'B'; return true;
        case KEY_C: outVirtualKey = 'C'; return true;
        case KEY_D: outVirtualKey = 'D'; return true;
        case KEY_E: outVirtualKey = 'E'; return true;
        case KEY_F: outVirtualKey = 'F'; return true;
        case KEY_G: outVirtualKey = 'G'; return true;
        case KEY_H: outVirtualKey = 'H'; return true;
        case KEY_I: outVirtualKey = 'I'; return true;
        case KEY_J: outVirtualKey = 'J'; return true;
        case KEY_K: outVirtualKey = 'K'; return true;
        case KEY_L: outVirtualKey = 'L'; return true;
        case KEY_M: outVirtualKey = 'M'; return true;
        case KEY_N: outVirtualKey = 'N'; return true;
        case KEY_O: outVirtualKey = 'O'; return true;
        case KEY_P: outVirtualKey = 'P'; return true;
        case KEY_Q: outVirtualKey = 'Q'; return true;
        case KEY_R: outVirtualKey = 'R'; return true;
        case KEY_S: outVirtualKey = 'S'; return true;
        case KEY_T: outVirtualKey = 'T'; return true;
        case KEY_U: outVirtualKey = 'U'; return true;
        case KEY_V: outVirtualKey = 'V'; return true;
        case KEY_W: outVirtualKey = 'W'; return true;
        case KEY_X: outVirtualKey = 'X'; return true;
        case KEY_Y: outVirtualKey = 'Y'; return true;
        case KEY_Z: outVirtualKey = 'Z'; return true;

        case KEY_0: outVirtualKey = '0'; return true;
        case KEY_1: outVirtualKey = '1'; return true;
        case KEY_2: outVirtualKey = '2'; return true;
        case KEY_3: outVirtualKey = '3'; return true;
        case KEY_4: outVirtualKey = '4'; return true;
        case KEY_5: outVirtualKey = '5'; return true;
        case KEY_6: outVirtualKey = '6'; return true;
        case KEY_7: outVirtualKey = '7'; return true;
        case KEY_8: outVirtualKey = '8'; return true;
        case KEY_9: outVirtualKey = '9'; return true;

        case KEY_SEMICOLON: outVirtualKey = 0xBA; return true;      // VK_OEM_1
        case KEY_EQUALS: outVirtualKey = 0xBB; return true;         // VK_OEM_PLUS
        case KEY_COMMA: outVirtualKey = 0xBC; return true;          // VK_OEM_COMMA
        case KEY_MINUS: outVirtualKey = 0xBD; return true;          // VK_OEM_MINUS
        case KEY_DOT: outVirtualKey = 0xBE; return true;            // VK_OEM_PERIOD
        case KEY_SLASH: outVirtualKey = 0xBF; return true;          // VK_OEM_2
        case KEY_BACKQUOTE: outVirtualKey = 0xC0; return true;      // VK_OEM_3
        case KEY_LEFT_BRACKET: outVirtualKey = 0xDB; return true;   // VK_OEM_4
        case KEY_BACK_SLASH: outVirtualKey = 0xDC; return true;     // VK_OEM_5
        case KEY_RIGHT_BRACKET: outVirtualKey = 0xDD; return true;  // VK_OEM_6
        case KEY_QUOTE: outVirtualKey = 0xDE; return true;          // VK_OEM_7
        default:
            return false;
    }
}

} // namespace phtv::windows_adapter
