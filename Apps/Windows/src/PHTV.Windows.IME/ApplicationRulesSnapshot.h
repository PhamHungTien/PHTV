#pragma once

#include <cstddef>
#include <cstdint>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace phtv::windows::ime {

inline constexpr std::size_t application_rules_snapshot_maximum_byte_length =
    64U * 1024U;
inline constexpr std::size_t application_rules_snapshot_maximum_rule_count =
    256;

enum class SnapshotApplicationRule : std::uint8_t {
    inherit = 0,
    prefer_english = 1,
    lock_english = 2,
};

struct ApplicationRuleSnapshot final {
    std::string executable_identity;
    std::string package_family_name;
    SnapshotApplicationRule rule{SnapshotApplicationRule::inherit};
};

struct ApplicationRulesSnapshot final {
    std::uint32_t schema_version{1};
    std::uint64_t revision{};
    std::vector<ApplicationRuleSnapshot> rules;
};

enum class ApplicationRulesDecodeStatus {
    ok,
    invalid_size,
    invalid_magic,
    unsupported_format,
    checksum_mismatch,
    unsupported_schema,
    invalid_record_count,
    invalid_payload_size,
    truncated_record,
    invalid_rule,
    invalid_flags,
    invalid_identity,
    duplicate_identity,
    allocation_failure,
};

[[nodiscard]] ApplicationRulesDecodeStatus decode_application_rules_snapshot(
    std::span<const std::uint8_t> contents,
    ApplicationRulesSnapshot& output
) noexcept;

/// Package-specific rules win over the executable-only fallback.
[[nodiscard]] SnapshotApplicationRule application_rule_for_identity(
    const ApplicationRulesSnapshot& snapshot,
    std::string_view executable_identity,
    std::string_view package_family_name
) noexcept;

}  // namespace phtv::windows::ime
