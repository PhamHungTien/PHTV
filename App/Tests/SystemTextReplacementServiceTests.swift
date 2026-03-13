import XCTest
@testable import PHTV

final class SystemTextReplacementServiceTests: XCTestCase {

    func testNormalizedEntriesIgnoreDisabledEmptyAndDuplicateItems() {
        let entries = PHTVSystemTextReplacementService.normalizedEntries(from: [
            ["on": 1, "replace": "dc", "with": "được"],
            ["on": 0, "replace": "kk", "with": "không biết"],
            ["on": 1, "replace": "  ", "with": "không hợp lệ"],
            ["on": 1, "replace": "dc", "with": "bị trùng"],
            ["replace": "ntn", "with": "như thế nào"]
        ])

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].shortcut, "dc")
        XCTAssertEqual(entries[0].expansion, "được")
        XCTAssertEqual(entries[1].shortcut, "ntn")
        XCTAssertEqual(entries[1].expansion, "như thế nào")
    }

    func testRuntimeMacrosKeepUserMacrosAndAppendUniqueSystemEntries() {
        let userMacros = [
            MacroItem(shortcut: "dc", expansion: "do custom"),
            MacroItem(shortcut: "mk", expansion: "mình")
        ]

        let merged = PHTVSystemTextReplacementService.mergedRuntimeMacros(
            userMacros: userMacros,
            useSystemTextReplacements: true,
            rawItems: [
                ["on": 1, "replace": "dc", "with": "được"],
                ["on": 1, "replace": "ntn", "with": "như thế nào"]
            ]
        )

        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(merged[0].shortcut, "dc")
        XCTAssertEqual(merged[0].expansion, "do custom")
        XCTAssertEqual(merged[1].shortcut, "mk")
        XCTAssertEqual(merged[1].expansion, "mình")
        XCTAssertEqual(merged[2].shortcut, "ntn")
        XCTAssertEqual(merged[2].expansion, "như thế nào")
    }
}
