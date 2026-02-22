#ifndef ENGINE_KEY_CODE_TYPES_INC
#define ENGINE_KEY_CODE_TYPES_INC

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

#endif /* ENGINE_KEY_CODE_TYPES_INC */
