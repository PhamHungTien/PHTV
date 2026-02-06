#pragma once

#include <vector>
#include "Engine.h"

namespace phtv::windows_host {

struct EngineOutput {
    Byte code = 0;
    Byte extCode = 0;
    Byte backspaceCount = 0;
    std::vector<Uint32> committedChars;
    std::vector<Uint32> macroChars;
};

class PHTVEngineSession {
public:
    PHTVEngineSession();

    void startSession();

    EngineOutput processKeyDown(Uint16 engineKeyCode,
                                Uint8 capsStatus,
                                bool hasOtherControlKey);

    void notifyMouseDown();

private:
    vKeyHookState* state_;
};

} // namespace phtv::windows_host
