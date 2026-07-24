#include <cstdint>
#include <iostream>
#include <string>
#include <utility>
#include <vector>

#include "ApplicationRulesSnapshot.h"

namespace {

using phtv::windows::ime::ApplicationRulesDecodeStatus;
using phtv::windows::ime::ApplicationRulesSnapshot;
using phtv::windows::ime::SnapshotApplicationRule;
using phtv::windows::ime::application_rule_for_identity;
using phtv::windows::ime::decode_application_rules_snapshot;

struct EncodedRule final {
    std::string executable;
    std::string package;
    std::uint8_t rule;
};

constexpr std::size_t header_length = 32;
constexpr std::size_t record_header_length = 8;
constexpr std::uint32_t fnv_offset_basis = 2166136261U;
constexpr std::uint32_t fnv_prime = 16777619U;

void write_u16(
    std::vector<std::uint8_t>& output,
    const std::size_t offset,
    const std::uint16_t value
) {
    output[offset] = static_cast<std::uint8_t>(value);
    output[offset + 1] = static_cast<std::uint8_t>(value >> 8U);
}

void write_u32(
    std::vector<std::uint8_t>& output,
    const std::size_t offset,
    const std::uint32_t value
) {
    for (std::size_t byte = 0; byte < 4; ++byte) {
        output[offset + byte] =
            static_cast<std::uint8_t>(value >> (byte * 8U));
    }
}

void write_u64(
    std::vector<std::uint8_t>& output,
    const std::size_t offset,
    const std::uint64_t value
) {
    for (std::size_t byte = 0; byte < 8; ++byte) {
        output[offset + byte] =
            static_cast<std::uint8_t>(value >> (byte * 8U));
    }
}

[[nodiscard]] std::uint32_t checksum(
    const std::vector<std::uint8_t>& contents,
    const std::size_t length
) noexcept {
    std::uint32_t result = fnv_offset_basis;
    for (std::size_t index = 0; index < length; ++index) {
        result ^= contents[index];
        result *= fnv_prime;
    }
    return result;
}

[[nodiscard]] std::vector<std::uint8_t> encode(
    const std::vector<EncodedRule>& rules,
    const std::uint64_t revision = 42
) {
    std::size_t payload_length{};
    for (const EncodedRule& rule : rules) {
        payload_length += record_header_length;
        payload_length += rule.executable.size();
        payload_length += rule.package.size();
    }

    std::vector<std::uint8_t> output(
        header_length + payload_length + 4,
        0
    );
    const std::string magic{"PHTVRUL"};
    for (std::size_t index = 0; index < magic.size(); ++index) {
        output[index] = static_cast<std::uint8_t>(magic[index]);
    }
    write_u16(output, 8, 1);
    write_u16(output, 10, static_cast<std::uint16_t>(header_length));
    write_u32(output, 12, 1);
    write_u64(output, 16, revision);
    write_u32(output, 24, static_cast<std::uint32_t>(rules.size()));
    write_u32(output, 28, static_cast<std::uint32_t>(payload_length));

    std::size_t offset = header_length;
    for (const EncodedRule& rule : rules) {
        output[offset] = rule.rule;
        output[offset + 1] = rule.package.empty() ? 0 : 1;
        write_u16(
            output,
            offset + 2,
            static_cast<std::uint16_t>(rule.executable.size())
        );
        write_u16(
            output,
            offset + 4,
            static_cast<std::uint16_t>(rule.package.size())
        );
        offset += record_header_length;
        for (const char character : rule.executable) {
            output[offset++] = static_cast<std::uint8_t>(character);
        }
        for (const char character : rule.package) {
            output[offset++] = static_cast<std::uint8_t>(character);
        }
    }
    write_u32(output, offset, checksum(output, offset));
    return output;
}

void refresh_checksum(std::vector<std::uint8_t>& contents) {
    const std::size_t offset = contents.size() - 4;
    write_u32(contents, offset, checksum(contents, offset));
}

[[nodiscard]] bool expect(
    const bool condition,
    const char* const message
) noexcept {
    if (!condition) {
        std::cerr << "FAILED: " << message << '\n';
    }
    return condition;
}

[[nodiscard]] bool valid_snapshot_decodes_and_matches() {
    const auto contents = encode({
        {"code.exe", "", 1},
        {"code.exe", "microsoft.code_8wekyb3d8bbwe", 2},
        {"notepad.exe", "", 2},
    });
    ApplicationRulesSnapshot snapshot;
    return expect(
            decode_application_rules_snapshot(contents, snapshot)
                == ApplicationRulesDecodeStatus::ok,
            "valid snapshot decodes"
        )
        && expect(snapshot.revision == 42, "revision decodes")
        && expect(snapshot.rules.size() == 3, "all rules decode")
        && expect(
            application_rule_for_identity(snapshot, "code.exe", "")
                == SnapshotApplicationRule::prefer_english,
            "executable fallback matches"
        )
        && expect(
            application_rule_for_identity(
                snapshot,
                "code.exe",
                "microsoft.code_8wekyb3d8bbwe"
            ) == SnapshotApplicationRule::lock_english,
            "package-specific rule wins"
        )
        && expect(
            application_rule_for_identity(
                snapshot,
                "unknown.exe",
                ""
            ) == SnapshotApplicationRule::inherit,
            "unknown application inherits"
        );
}

[[nodiscard]] bool cross_language_golden_vector_matches() {
    const std::vector<std::uint8_t> expected{
        0x50, 0x48, 0x54, 0x56, 0x52, 0x55, 0x4C, 0x00,
        0x01, 0x00, 0x20, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01,
        0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x63, 0x6F, 0x64, 0x65, 0x2E, 0x65, 0x78, 0x65,
        0x11, 0x59, 0xA5, 0x1E,
    };
    const auto encoded = encode(
        {{"code.exe", "", 1}},
        0x0102030405060708ULL
    );
    ApplicationRulesSnapshot snapshot;
    return expect(encoded == expected, "C++ encoder matches golden vector")
        && expect(
            decode_application_rules_snapshot(expected, snapshot)
                == ApplicationRulesDecodeStatus::ok,
            "cross-language golden vector decodes"
        )
        && expect(
            snapshot.revision == 0x0102030405060708ULL,
            "golden revision decodes"
        );
}

[[nodiscard]] bool malformed_snapshots_are_rejected() {
    const auto base = encode({{"code.exe", "", 1}});
    ApplicationRulesSnapshot snapshot;

    auto corrupted = base;
    corrupted[32] ^= 1U;
    if (!expect(
            decode_application_rules_snapshot(corrupted, snapshot)
                == ApplicationRulesDecodeStatus::checksum_mismatch,
            "checksum mismatch"
        )) {
        return false;
    }

    auto unknown_rule = base;
    unknown_rule[32] = 3;
    refresh_checksum(unknown_rule);
    if (!expect(
            decode_application_rules_snapshot(unknown_rule, snapshot)
                == ApplicationRulesDecodeStatus::invalid_rule,
            "unknown rule"
        )) {
        return false;
    }

    auto path_identity = encode({{"c:\\code.exe", "", 1}});
    if (!expect(
            decode_application_rules_snapshot(path_identity, snapshot)
                == ApplicationRulesDecodeStatus::invalid_identity,
            "path identity"
        )) {
        return false;
    }

    auto uppercase_identity = encode({{"Code.exe", "", 1}});
    if (!expect(
            decode_application_rules_snapshot(uppercase_identity, snapshot)
                == ApplicationRulesDecodeStatus::invalid_identity,
            "non-normalized identity"
        )) {
        return false;
    }

    auto invalid_utf8 = encode({{"code.exe", "", 1}});
    invalid_utf8[40] = 0xC0U;
    refresh_checksum(invalid_utf8);
    if (!expect(
            decode_application_rules_snapshot(invalid_utf8, snapshot)
                == ApplicationRulesDecodeStatus::invalid_identity,
            "invalid UTF-8"
        )) {
        return false;
    }

    const auto duplicate = encode({
        {"code.exe", "", 1},
        {"code.exe", "", 2},
    });
    return expect(
        decode_application_rules_snapshot(duplicate, snapshot)
            == ApplicationRulesDecodeStatus::duplicate_identity,
        "duplicate identity"
    );
}

}  // namespace

int main() {
    if (!cross_language_golden_vector_matches()
        || !valid_snapshot_decodes_and_matches()
        || !malformed_snapshots_are_rejected()) {
        return 1;
    }
    std::cout << "PHTV Windows application rules snapshot tests passed\n";
    return 0;
}
