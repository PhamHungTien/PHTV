#pragma once

#include "SettingsSnapshot.h"

namespace phtv::windows::ime {

/// Loads the per-user runtime snapshot. Missing, unreadable, or unsupported
/// files deliberately produce the safe defaults declared by SettingsSnapshot.
[[nodiscard]] SettingsSnapshot load_user_settings_snapshot() noexcept;

}  // namespace phtv::windows::ime
