#include "ApplicationRulesSnapshot.h"

#include <algorithm>
#include <array>
#include <limits>
#include <new>
#include <utility>

namespace phtv::windows::ime {
namespace {

constexpr std::array<std::uint8_t, 8> magic{
    'P', 'H', 'T', 'V', 'R', 'U', 'L', 0,
};
constexpr std::uint16_t current_format_version = 1;
constexpr std::uint32_t current_schema_version = 1;
constexpr std::size_t header_byte_length = 32;
constexpr std::size_t record_header_byte_length = 8;
constexpr std::size_t checksum_byte_length = 4;
constexpr std::size_t format_version_offset = 8;
constexpr std::size_t header_length_offset = 10;
constexpr std::size_t schema_version_offset = 12;
constexpr std::size_t revision_offset = 16;
constexpr std::size_t record_count_offset = 24;
constexpr std::size_t payload_length_offset = 28;
constexpr std::uint8_t has_package_family_flag = 1U << 0U;
constexpr std::uint8_t known_record_flags = has_package_family_flag;
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

[[nodiscard]] bool is_continuation_byte(const std::uint8_t value) noexcept {
    return (value & 0xC0U) == 0x80U;
}

[[nodiscard]] bool is_valid_utf8(
    const std::span<const std::uint8_t> value
) noexcept {
    std::size_t index{};
    while (index < value.size()) {
        const std::uint8_t lead = value[index];
        if (lead <= 0x7FU) {
            ++index;
            continue;
        }

        if (lead >= 0xC2U && lead <= 0xDFU) {
            if (index + 1 >= value.size()
                || !is_continuation_byte(value[index + 1])) {
                return false;
            }
            index += 2;
            continue;
        }

        if (lead >= 0xE0U && lead <= 0xEFU) {
            if (index + 2 >= value.size()
                || !is_continuation_byte(value[index + 1])
                || !is_continuation_byte(value[index + 2])
                || (lead == 0xE0U && value[index + 1] < 0xA0U)
                || (lead == 0xEDU && value[index + 1] >= 0xA0U)) {
                return false;
            }
            index += 3;
            continue;
        }

        if (lead >= 0xF0U && lead <= 0xF4U) {
            if (index + 3 >= value.size()
                || !is_continuation_byte(value[index + 1])
                || !is_continuation_byte(value[index + 2])
                || !is_continuation_byte(value[index + 3])
                || (lead == 0xF0U && value[index + 1] < 0x90U)
                || (lead == 0xF4U && value[index + 1] >= 0x90U)) {
                return false;
            }
            index += 4;
            continue;
        }
        return false;
    }
    return true;
}

[[nodiscard]] bool is_valid_executable_identity(
    const std::span<const std::uint8_t> value
) noexcept {
    if (value.size() < 5 || !is_valid_utf8(value)) {
        return false;
    }
    for (const std::uint8_t character : value) {
        if (character == 0
            || character == '/'
            || character == '\\'
            || character == ':'
            || (character >= 'A' && character <= 'Z')) {
            return false;
        }
    }
    constexpr std::array<std::uint8_t, 4> suffix{'.', 'e', 'x', 'e'};
    return std::equal(
        suffix.begin(),
        suffix.end(),
        value.end() - static_cast<std::ptrdiff_t>(suffix.size())
    );
}

[[nodiscard]] bool is_valid_package_family_name(
    const std::span<const std::uint8_t> value
) noexcept {
    if (value.empty()) {
        return true;
    }
    return std::all_of(value.begin(), value.end(), [](const std::uint8_t item) {
        return (item >= 'a' && item <= 'z')
            || (item >= '0' && item <= '9')
            || item == '.'
            || item == '_'
            || item == '-';
    });
}

[[nodiscard]] bool has_duplicate(
    const std::vector<ApplicationRuleSnapshot>& rules,
    const std::string_view executable,
    const std::string_view package
) noexcept {
    return std::any_of(
        rules.begin(),
        rules.end(),
        [&](const ApplicationRuleSnapshot& existing) {
            return existing.executable_identity == executable
                && existing.package_family_name == package;
        }
    );
}

}  // namespace

ApplicationRulesDecodeStatus decode_application_rules_snapshot(
    const std::span<const std::uint8_t> contents,
    ApplicationRulesSnapshot& output
) noexcept {
    if (contents.size() < header_byte_length + checksum_byte_length
        || contents.size() > application_rules_snapshot_maximum_byte_length) {
        return ApplicationRulesDecodeStatus::invalid_size;
    }
    if (!std::equal(magic.begin(), magic.end(), contents.begin())) {
        return ApplicationRulesDecodeStatus::invalid_magic;
    }
    if (read_u16(contents, format_version_offset) != current_format_version
        || read_u16(contents, header_length_offset) != header_byte_length) {
        return ApplicationRulesDecodeStatus::unsupported_format;
    }

    const std::size_t checksum_offset =
        contents.size() - checksum_byte_length;
    if (read_u32(contents, checksum_offset)
        != checksum(contents.first(checksum_offset))) {
        return ApplicationRulesDecodeStatus::checksum_mismatch;
    }

    const std::uint32_t schema_version =
        read_u32(contents, schema_version_offset);
    if (schema_version != current_schema_version) {
        return ApplicationRulesDecodeStatus::unsupported_schema;
    }

    const std::uint32_t record_count =
        read_u32(contents, record_count_offset);
    if (record_count > application_rules_snapshot_maximum_rule_count) {
        return ApplicationRulesDecodeStatus::invalid_record_count;
    }

    const std::uint32_t payload_length =
        read_u32(contents, payload_length_offset);
    if (static_cast<std::size_t>(payload_length)
        != checksum_offset - header_byte_length) {
        return ApplicationRulesDecodeStatus::invalid_payload_size;
    }

    try {
        ApplicationRulesSnapshot decoded;
        decoded.schema_version = schema_version;
        decoded.revision = read_u64(contents, revision_offset);
        decoded.rules.reserve(record_count);

        std::size_t offset = header_byte_length;
        for (std::uint32_t index = 0; index < record_count; ++index) {
            if (offset > checksum_offset
                    || checksum_offset - offset < record_header_byte_length) {
                return ApplicationRulesDecodeStatus::truncated_record;
            }

            const auto raw_rule = contents[offset];
            const auto flags = contents[offset + 1];
            const std::size_t executable_length =
                read_u16(contents, offset + 2);
            const std::size_t package_length =
                read_u16(contents, offset + 4);
            const auto reserved = read_u16(contents, offset + 6);
            offset += record_header_byte_length;

            if (raw_rule
                    < static_cast<std::uint8_t>(
                        SnapshotApplicationRule::prefer_english
                    )
                || raw_rule
                    > static_cast<std::uint8_t>(
                        SnapshotApplicationRule::lock_english
                    )) {
                return ApplicationRulesDecodeStatus::invalid_rule;
            }
            const bool has_package =
                (flags & has_package_family_flag) != 0;
            if ((flags & ~known_record_flags) != 0
                || reserved != 0
                || has_package != (package_length != 0)) {
                return ApplicationRulesDecodeStatus::invalid_flags;
            }
            if (executable_length == 0
                || executable_length
                    > std::numeric_limits<std::size_t>::max()
                        - package_length
                || offset > checksum_offset
                || executable_length + package_length
                    > checksum_offset - offset) {
                return ApplicationRulesDecodeStatus::truncated_record;
            }

            const auto executable_bytes =
                contents.subspan(offset, executable_length);
            offset += executable_length;
            const auto package_bytes =
                contents.subspan(offset, package_length);
            offset += package_length;
            if (!is_valid_executable_identity(executable_bytes)
                || !is_valid_package_family_name(package_bytes)) {
                return ApplicationRulesDecodeStatus::invalid_identity;
            }

            const std::string executable(
                reinterpret_cast<const char*>(executable_bytes.data()),
                executable_bytes.size()
            );
            const std::string package(
                reinterpret_cast<const char*>(package_bytes.data()),
                package_bytes.size()
            );
            if (has_duplicate(decoded.rules, executable, package)) {
                return ApplicationRulesDecodeStatus::duplicate_identity;
            }

            decoded.rules.push_back({
                .executable_identity = executable,
                .package_family_name = package,
                .rule = static_cast<SnapshotApplicationRule>(raw_rule),
            });
        }

        if (offset != checksum_offset) {
            return ApplicationRulesDecodeStatus::invalid_payload_size;
        }
        output = std::move(decoded);
        return ApplicationRulesDecodeStatus::ok;
    } catch (const std::bad_alloc&) {
        return ApplicationRulesDecodeStatus::allocation_failure;
    } catch (...) {
        return ApplicationRulesDecodeStatus::invalid_identity;
    }
}

SnapshotApplicationRule application_rule_for_identity(
    const ApplicationRulesSnapshot& snapshot,
    const std::string_view executable_identity,
    const std::string_view package_family_name
) noexcept {
    SnapshotApplicationRule fallback = SnapshotApplicationRule::inherit;
    for (const ApplicationRuleSnapshot& candidate : snapshot.rules) {
        if (candidate.executable_identity != executable_identity) {
            continue;
        }
        if (candidate.package_family_name.empty()) {
            fallback = candidate.rule;
            continue;
        }
        if (!package_family_name.empty()
            && candidate.package_family_name == package_family_name) {
            return candidate.rule;
        }
    }
    return fallback;
}

}  // namespace phtv::windows::ime
