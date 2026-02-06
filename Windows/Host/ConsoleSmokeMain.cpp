#include <iostream>
#include "PHTVEngineSession.h"
#include "Win32KeycodeAdapter.h"
#include "EngineGlobals.h"

int main() {
    phtv::windows_runtime::resetEngineDefaults();
    phtv::windows_host::PHTVEngineSession session;

    std::cout << "PHTV Windows engine smoke host\n";
    std::cout << "Enter a Win32 virtual-key code (decimal), 0 to exit.\n";

    while (true) {
        unsigned int vk = 0;
        std::cout << "> ";
        if (!(std::cin >> vk) || vk == 0) {
            break;
        }

        Uint16 engineKey = 0;
        if (!phtv::windows_adapter::mapVirtualKeyToEngine(vk, engineKey)) {
            std::cout << "Unhandled key\n";
            continue;
        }

        auto out = session.processKeyDown(engineKey, 0, false);
        std::cout << "code=" << static_cast<int>(out.code)
                  << " ext=" << static_cast<int>(out.extCode)
                  << " backspace=" << static_cast<int>(out.backspaceCount)
                  << " newChars=" << out.committedChars.size()
                  << " macroChars=" << out.macroChars.size() << "\n";
    }

    return 0;
}
