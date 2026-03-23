//
//  SystemTextReplacementServiceTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

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
        XCTAssertEqual(merged[0].snippetType, .systemTextReplacement)
        XCTAssertEqual(merged[1].shortcut, "mk")
        XCTAssertEqual(merged[1].expansion, "mình")
        XCTAssertEqual(merged[1].snippetType, .static)
        XCTAssertEqual(merged[2].shortcut, "ntn")
        XCTAssertEqual(merged[2].expansion, "như thế nào")
        XCTAssertEqual(merged[2].snippetType, .systemTextReplacement)
    }

    func testRuntimeMacrosDoNotChangeTypesWhenSystemReplacementDisabled() {
        let userMacros = [
            MacroItem(shortcut: "dc", expansion: "do custom"),
            MacroItem(shortcut: "mk", expansion: "mình")
        ]

        let merged = PHTVSystemTextReplacementService.mergedRuntimeMacros(
            userMacros: userMacros,
            useSystemTextReplacements: false,
            rawItems: [
                ["on": 1, "replace": "dc", "with": "được"],
                ["on": 1, "replace": "ntn", "with": "như thế nào"]
            ]
        )

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].snippetType, .static)
        XCTAssertEqual(merged[1].snippetType, .static)
    }

    func testNativeTextReplacementDeferralUsesGuiDefaultAndToolingFallback() {
        XCTAssertTrue(
            PHTVSystemTextReplacementService.shouldDeferToNativeTextReplacement(
                forBundleId: "com.google.Chrome"
            )
        )
        XCTAssertTrue(
            PHTVSystemTextReplacementService.shouldDeferToNativeTextReplacement(
                forBundleId: "com.tinyspeck.slackmacgap"
            )
        )
        XCTAssertTrue(
            PHTVSystemTextReplacementService.shouldDeferToNativeTextReplacement(
                forBundleId: "com.apple.TextEdit"
            )
        )
        XCTAssertFalse(
            PHTVSystemTextReplacementService.shouldDeferToNativeTextReplacement(
                forBundleId: "com.apple.Terminal"
            )
        )
        XCTAssertFalse(
            PHTVSystemTextReplacementService.shouldDeferToNativeTextReplacement(
                forBundleId: "com.microsoft.vscode"
            )
        )
        XCTAssertFalse(
            PHTVSystemTextReplacementService.shouldDeferToNativeTextReplacement(
                forBundleId: nil
            )
        )
    }
}
