#pragma once

#include <cstdint>
#include "DataType.h"

namespace phtv::linux_adapter {

// Maps Linux keysym-like values to internal engine key ids.
// Accepts ASCII for letters/digits and common X11 keysyms for controls.
bool mapKeySymToEngine(std::uint32_t keySym, Uint16& outEngineKey);

} // namespace phtv::linux_adapter
