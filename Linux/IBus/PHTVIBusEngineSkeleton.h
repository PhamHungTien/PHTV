#pragma once

#include "PHTVEngineSession.h"

namespace phtv::linux_ibus {

// Foundation class for future IBus/Fcitx bridge.
class PHTVIBusEngineSkeleton {
public:
    bool initialize();
    void shutdown();

    phtv::linux_host::EngineOutput handleMappedEngineKey(Uint16 engineKey,
                                                          bool isCaps,
                                                          bool hasOtherControlKey);

private:
    phtv::linux_host::PHTVEngineSession session_;
};

} // namespace phtv::linux_ibus
