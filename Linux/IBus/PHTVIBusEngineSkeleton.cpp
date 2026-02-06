#include "PHTVIBusEngineSkeleton.h"

namespace phtv::linux_ibus {

bool PHTVIBusEngineSkeleton::initialize() {
    session_.startSession();
    return true;
}

void PHTVIBusEngineSkeleton::shutdown() {
    // Reserved for future IBus resource teardown.
}

phtv::linux_host::EngineOutput PHTVIBusEngineSkeleton::handleMappedEngineKey(
    Uint16 engineKey,
    bool isCaps,
    bool hasOtherControlKey) {
    return session_.processKeyDown(engineKey, isCaps, hasOtherControlKey);
}

} // namespace phtv::linux_ibus
