#include "LinuxKeycodeAdapter.h"

namespace {
constexpr std::uint32_t XK_BackSpace = 0xFF08;
constexpr std::uint32_t XK_Tab = 0xFF09;
constexpr std::uint32_t XK_Return = 0xFF0D;
constexpr std::uint32_t XK_Escape = 0xFF1B;
constexpr std::uint32_t XK_Left = 0xFF51;
constexpr std::uint32_t XK_Up = 0xFF52;
constexpr std::uint32_t XK_Right = 0xFF53;
constexpr std::uint32_t XK_Down = 0xFF54;
} // namespace

namespace phtv::linux_adapter {

bool mapKeySymToEngine(std::uint32_t keySym, Uint16& outEngineKey) {
    switch (keySym) {
        case XK_Escape: outEngineKey = KEY_ESC; return true;
        case XK_BackSpace: outEngineKey = KEY_DELETE; return true;
        case XK_Tab: outEngineKey = KEY_TAB; return true;
        case XK_Return: outEngineKey = KEY_RETURN; return true;
        case XK_Left: outEngineKey = KEY_LEFT; return true;
        case XK_Up: outEngineKey = KEY_UP; return true;
        case XK_Right: outEngineKey = KEY_RIGHT; return true;
        case XK_Down: outEngineKey = KEY_DOWN; return true;
        case ' ': outEngineKey = KEY_SPACE; return true;

        case 'a': case 'A': outEngineKey = KEY_A; return true;
        case 'b': case 'B': outEngineKey = KEY_B; return true;
        case 'c': case 'C': outEngineKey = KEY_C; return true;
        case 'd': case 'D': outEngineKey = KEY_D; return true;
        case 'e': case 'E': outEngineKey = KEY_E; return true;
        case 'f': case 'F': outEngineKey = KEY_F; return true;
        case 'g': case 'G': outEngineKey = KEY_G; return true;
        case 'h': case 'H': outEngineKey = KEY_H; return true;
        case 'i': case 'I': outEngineKey = KEY_I; return true;
        case 'j': case 'J': outEngineKey = KEY_J; return true;
        case 'k': case 'K': outEngineKey = KEY_K; return true;
        case 'l': case 'L': outEngineKey = KEY_L; return true;
        case 'm': case 'M': outEngineKey = KEY_M; return true;
        case 'n': case 'N': outEngineKey = KEY_N; return true;
        case 'o': case 'O': outEngineKey = KEY_O; return true;
        case 'p': case 'P': outEngineKey = KEY_P; return true;
        case 'q': case 'Q': outEngineKey = KEY_Q; return true;
        case 'r': case 'R': outEngineKey = KEY_R; return true;
        case 's': case 'S': outEngineKey = KEY_S; return true;
        case 't': case 'T': outEngineKey = KEY_T; return true;
        case 'u': case 'U': outEngineKey = KEY_U; return true;
        case 'v': case 'V': outEngineKey = KEY_V; return true;
        case 'w': case 'W': outEngineKey = KEY_W; return true;
        case 'x': case 'X': outEngineKey = KEY_X; return true;
        case 'y': case 'Y': outEngineKey = KEY_Y; return true;
        case 'z': case 'Z': outEngineKey = KEY_Z; return true;

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

        case '[': outEngineKey = KEY_LEFT_BRACKET; return true;
        case ']': outEngineKey = KEY_RIGHT_BRACKET; return true;
        case '`': outEngineKey = KEY_BACKQUOTE; return true;
        case '-': outEngineKey = KEY_MINUS; return true;
        case '=': outEngineKey = KEY_EQUALS; return true;
        case '\\': outEngineKey = KEY_BACK_SLASH; return true;
        case ';': outEngineKey = KEY_SEMICOLON; return true;
        case '\'': outEngineKey = KEY_QUOTE; return true;
        case ',': outEngineKey = KEY_COMMA; return true;
        case '.': outEngineKey = KEY_DOT; return true;
        case '/': outEngineKey = KEY_SLASH; return true;

        default:
            return false;
    }
}

} // namespace phtv::linux_adapter
