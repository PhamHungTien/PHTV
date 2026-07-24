#pragma once

#include "ApplicationRulesSnapshot.h"
#include "SettingsSnapshot.h"

namespace phtv::windows::ime {

/// Loads the per-user runtime snapshot. Missing, unreadable, or unsupported
/// files deliberately produce the safe defaults declared by SettingsSnapshot.
[[nodiscard]] SettingsSnapshot load_user_settings_snapshot() noexcept;

/// Loads only a rules snapshot written in the same logical transaction as the
/// control snapshot. A missing, malformed, or mismatched revision yields no
/// application-specific rules.
[[nodiscard]] ApplicationRulesSnapshot load_user_application_rules_snapshot(
    std::uint64_t expected_revision
) noexcept;

}  // namespace phtv::windows::ime
