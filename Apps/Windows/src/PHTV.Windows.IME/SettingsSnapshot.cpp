#include "SettingsSnapshot.h"

#include <algorithm>
#include <array>

namespace phtv::windows::ime {
namespace {

constexpr std::array<std::uint8_t, 8> magic{
    'P', 'H', 'T', 'V', 'C', 'F', 'G', 0,
};
constexpr std::uint16_t current_format_version = 1;
constexpr std::uint32_t current_schema_version = 1;
constexpr std::uint32_t vietnamese_enabled_flag = 1U << 0U;
constexpr std::uint32_t known_flags = vietnamese_enabled_flag;
constexpr std::size_t format_version_offset = 8;
constexpr std::size_t byte_length_offset = 10;
constexpr std::size_t schema_version_offset = 12;
constexpr std::size_t revision_offset = 16;
constexpr std::size_t flags_offset = 24;
constexpr std::size_t input_method_offset = 28;
constexpr std::size_t checksum_offset = 32;
constexpr std::uint32_t fnv_offset_basis = 2166136261U;
constexpr std::uint32_t fnv_prime = 16777619U;

[[nodiscard]] constexpr std::uint16_t read_u16(
    const std::span<const std::uint8_t> contents,
    const std::size_t offset
) noexcept {
    return static_cast<std::uint16_t>(contents[offset])
        | static_cast<std::uint16_t>(contents[offset + 1]) << 8U;
}

[[nodiscard]] constexpr std::uint32_t read_u32(
    const std::span<const std::uint8_t> contents,
    const std::size_t offset
) noexcept {
    return static_cast<std::uint32_t>(contents[offset])
        | static_cast<std::uint32_t>(contents[offset + 1]) << 8U
        | static_cast<std::uint32_t>(contents[offset + 2]) << 16U
        | static_cast<std::uint32_t>(contents[offset + 3]) << 24U;
}

[[nodiscard]] constexpr std::uint64_t read_u64(
    const std::span<const std::uint8_t> contents,
    const std::size_t offset
) noexcept {
    return static_cast<std::uint64_t>(read_u32(contents, offset))
        | static_cast<std::uint64_t>(read_u32(contents, offset + 4)) << 32U;
}

[[nodiscard]] constexpr std::uint32_t checksum(
    const std::span<const std::uint8_t> contents
) noexcept {
    std::uint32_t result = fnv_offset_basis;
    for (const std::uint8_t value : contents) {
        result ^= value;
        result *= fnv_prime;
    }
    return result;
}

}  // namespace

SnapshotDecodeStatus decode_settings_snapshot(
    const std::span<const std::uint8_t> contents,
    SettingsSnapshot& output
) noexcept {
    if (contents.size() != settings_snapshot_byte_length) {
        return SnapshotDecodeStatus::invalid_size;
    }
    if (!std::equal(magic.begin(), magic.end(), contents.begin())) {
        return SnapshotDecodeStatus::invalid_magic;
    }
    if (read_u16(contents, format_version_offset) != current_format_version
        || read_u16(contents, byte_length_offset)
            != settings_snapshot_byte_length) {
        return SnapshotDecodeStatus::unsupported_format;
    }
    if (read_u32(contents, checksum_offset)
        != checksum(contents.first(checksum_offset))) {
        return SnapshotDecodeStatus::checksum_mismatch;
    }

    const std::uint32_t schema_version =
        read_u32(contents, schema_version_offset);
    if (schema_version != current_schema_version) {
        return SnapshotDecodeStatus::unsupported_schema;
    }

    const std::uint32_t flags = read_u32(contents, flags_offset);
    if ((flags & ~known_flags) != 0) {
        return SnapshotDecodeStatus::invalid_flags;
    }

    const std::uint32_t input_method =
        read_u32(contents, input_method_offset);
    if (input_method
        > static_cast<std::uint32_t>(SnapshotInputMethod::vni)) {
        return SnapshotDecodeStatus::invalid_input_method;
    }

    SettingsSnapshot decoded;
    decoded.schema_version = schema_version;
    decoded.revision = read_u64(contents, revision_offset);
    decoded.vietnamese_enabled =
        (flags & vietnamese_enabled_flag) != 0;
    decoded.input_method = static_cast<SnapshotInputMethod>(input_method);
    output = decoded;
    return SnapshotDecodeStatus::ok;
}

}  // namespace phtv::windows::ime
