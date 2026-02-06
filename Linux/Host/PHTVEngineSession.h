#pragma once

#include <vector>
#include "Engine.h"

namespace phtv::linux_host {

struct EngineOutput {
    Byte code = 0;
    Byte extCode = 0;
    Byte backspaceCount = 0;
    std::vector<Uint32> committedChars;
};

class PHTVEngineSession {
public:
    PHTVEngineSession();

    void startSession();

    EngineOutput processKeyDown(Uint16 engineKeyCode,
                                bool isCaps,
                                bool hasOtherControlKey);

private:
    vKeyHookState* state_;
};

} // namespace phtv::linux_host
