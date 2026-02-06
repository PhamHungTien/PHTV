#include <iostream>
#include "PHTVEngineSession.h"
#include "LinuxKeycodeAdapter.h"
#include "EngineGlobals.h"

int main() {
    phtv::linux_runtime::resetEngineDefaults();
    phtv::linux_host::PHTVEngineSession session;

    std::cout << "PHTV Linux engine smoke host\n";
    std::cout << "Enter keysym value (decimal), 0 to exit.\n";

    while (true) {
        unsigned int keySym = 0;
        std::cout << "> ";
        if (!(std::cin >> keySym) || keySym == 0) {
            break;
        }

        Uint16 engineKey = 0;
        if (!phtv::linux_adapter::mapKeySymToEngine(keySym, engineKey)) {
            std::cout << "Unhandled key\n";
            continue;
        }

        auto out = session.processKeyDown(engineKey, false, false);
        std::cout << "code=" << static_cast<int>(out.code)
                  << " ext=" << static_cast<int>(out.extCode)
                  << " backspace=" << static_cast<int>(out.backspaceCount)
                  << " newChars=" << out.committedChars.size() << "\n";
    }

    return 0;
}
