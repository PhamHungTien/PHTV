#pragma once

#include <cstdint>
#include "DataType.h"

namespace phtv::windows_adapter {

// Map Win32 virtual key to internal engine key id.
// Returns false when the key is not handled by the engine.
bool mapVirtualKeyToEngine(std::uint32_t virtualKey, Uint16& outEngineKey);

// Reverse mapping for synthesizing key events from engine key ids.
// Returns false when no Win32 virtual key equivalent is available.
bool mapEngineKeyToVirtualKey(Uint16 engineKey, std::uint16_t& outVirtualKey);

} // namespace phtv::windows_adapter
