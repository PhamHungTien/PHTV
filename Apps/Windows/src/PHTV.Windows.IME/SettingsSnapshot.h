#pragma once

#include <cstddef>
#include <cstdint>
#include <span>

namespace phtv::windows::ime {

inline constexpr std::size_t settings_snapshot_byte_length = 36;

enum class SnapshotInputMethod : std::uint32_t {
    telex = 0,
    vni = 1,
};

struct SettingsSnapshot final {
    std::uint32_t schema_version{1};
    std::uint64_t revision{};
    bool vietnamese_enabled{true};
    SnapshotInputMethod input_method{SnapshotInputMethod::telex};
};

enum class SnapshotDecodeStatus {
    ok,
    invalid_size,
    invalid_magic,
    unsupported_format,
    checksum_mismatch,
    unsupported_schema,
    invalid_flags,
    invalid_input_method,
};

[[nodiscard]] SnapshotDecodeStatus decode_settings_snapshot(
    std::span<const std::uint8_t> contents,
    SettingsSnapshot& output
) noexcept;

}  // namespace phtv::windows::ime
