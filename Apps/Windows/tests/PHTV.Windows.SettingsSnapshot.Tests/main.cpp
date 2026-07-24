#include <array>
#include <cstdint>
#include <iostream>
#include <span>

#include "SettingsSnapshot.h"

namespace {

using phtv::windows::ime::SettingsSnapshot;
using phtv::windows::ime::SnapshotDecodeStatus;
using phtv::windows::ime::SnapshotInputMethod;
using phtv::windows::ime::decode_settings_snapshot;

constexpr std::uint32_t fnv_offset_basis = 2166136261U;
constexpr std::uint32_t fnv_prime = 16777619U;
constexpr std::size_t checksum_offset = 32;

[[nodiscard]] bool expect(
    const bool condition,
    const char* const message
) noexcept {
    if (!condition) {
        std::cerr << "FAILED: " << message << '\n';
    }
    return condition;
}

void refresh_checksum(
    std::array<std::uint8_t, 36>& contents
) noexcept {
    std::uint32_t checksum = fnv_offset_basis;
    for (std::size_t index = 0; index < checksum_offset; ++index) {
        checksum ^= contents[index];
        checksum *= fnv_prime;
    }
    for (std::size_t index = 0; index < 4; ++index) {
        contents[checksum_offset + index] =
            static_cast<std::uint8_t>(checksum >> (index * 8U));
    }
}

[[nodiscard]] constexpr std::array<std::uint8_t, 36> golden_vector() {
    return {
        0x50, 0x48, 0x54, 0x56, 0x43, 0x46, 0x47, 0x00,
        0x01, 0x00, 0x24, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x6C, 0x05, 0xA6, 0xE9,
    };
}

[[nodiscard]] bool golden_vector_decodes() noexcept {
    const auto contents = golden_vector();
    SettingsSnapshot decoded;
    const SnapshotDecodeStatus status =
        decode_settings_snapshot(contents, decoded);
    return expect(status == SnapshotDecodeStatus::ok, "golden status")
        && expect(decoded.schema_version == 1, "schema version")
        && expect(
            decoded.revision == 0x0102030405060708ULL,
            "revision"
        )
        && expect(!decoded.vietnamese_enabled, "Vietnamese disabled")
        && expect(
            decoded.input_method == SnapshotInputMethod::vni,
            "VNI input method"
        );
}

[[nodiscard]] bool malformed_snapshots_are_rejected() noexcept {
    auto corrupted = golden_vector();
    corrupted[24] ^= 1U;
    SettingsSnapshot decoded;
    bool passed = expect(
        decode_settings_snapshot(corrupted, decoded)
            == SnapshotDecodeStatus::checksum_mismatch,
        "checksum mismatch"
    );

    const auto valid = golden_vector();
    passed = expect(
        decode_settings_snapshot(
            std::span<const std::uint8_t>(valid).first(valid.size() - 1),
            decoded
        ) == SnapshotDecodeStatus::invalid_size,
        "truncated snapshot"
    ) && passed;

    auto future_format = golden_vector();
    future_format[8] = 2;
    passed = expect(
        decode_settings_snapshot(future_format, decoded)
            == SnapshotDecodeStatus::unsupported_format,
        "future format"
    ) && passed;

    auto future_schema = golden_vector();
    future_schema[12] = 2;
    refresh_checksum(future_schema);
    passed = expect(
        decode_settings_snapshot(future_schema, decoded)
            == SnapshotDecodeStatus::unsupported_schema,
        "future schema"
    ) && passed;

    auto unknown_flags = golden_vector();
    unknown_flags[24] = 2;
    refresh_checksum(unknown_flags);
    passed = expect(
        decode_settings_snapshot(unknown_flags, decoded)
            == SnapshotDecodeStatus::invalid_flags,
        "unknown flags"
    ) && passed;

    auto unknown_method = golden_vector();
    unknown_method[28] = 2;
    refresh_checksum(unknown_method);
    passed = expect(
        decode_settings_snapshot(unknown_method, decoded)
            == SnapshotDecodeStatus::invalid_input_method,
        "unknown input method"
    ) && passed;
    return passed;
}

}  // namespace

int main() {
    if (!golden_vector_decodes()
        || !malformed_snapshots_are_rejected()) {
        return 1;
    }
    std::cout << "PHTV Windows runtime settings snapshot tests passed\n";
    return 0;
}
