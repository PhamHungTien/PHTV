//
//  ClipboardItemHotkeyTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
import AppKit
@testable import PHTV

final class ClipboardItemHotkeyTests: XCTestCase {
    private let hotkey = ClipboardItemHotkey(modifiers: [.control, .option], keyCode: KeyCode.vKey)

    func testHotkeyRequiresARealKeyAndModifier() {
        XCTAssertTrue(hotkey.isValid)
        XCTAssertFalse(ClipboardItemHotkey(modifiers: [], keyCode: KeyCode.vKey).isValid)
        XCTAssertFalse(ClipboardItemHotkey(modifiers: [.control], keyCode: KeyCode.noKey).isValid)
    }

    func testPinnedHistoryHotkeyRoundTripsAndClearsWhenUnpinned() throws {
        let original = ClipboardHistoryItem(
            id: UUID(),
            timestamp: Date(),
            textContent: "Dán nhanh",
            imageData: nil,
            filePaths: nil,
            sourceApp: nil,
            isPinned: true,
            hotkey: hotkey
        )

        let decoded = try JSONDecoder().decode(
            ClipboardHistoryItem.self,
            from: JSONEncoder().encode(original)
        )

        XCTAssertEqual(decoded.hotkey, hotkey)
        XCTAssertEqual(decoded.withPinned(false).hotkey, nil)
        XCTAssertEqual(decoded.withPinned(false).withPinned(true).hotkey, nil)
    }

    func testSavedItemHotkeySurvivesEditingAndJSONRoundTrip() throws {
        var library = ClipboardSavedLibrary()
        let saved = try library.saveItem(
            title: "Chữ ký",
            content: "Trân trọng,",
            groupID: nil,
            hotkey: hotkey
        )

        let edited = try library.saveItem(
            id: saved.id,
            title: "Chữ ký mới",
            content: "Trân trọng,\nTiến",
            groupID: nil,
            hotkey: hotkey
        )
        let decoded = try JSONDecoder().decode(
            ClipboardSavedLibrary.self,
            from: JSONEncoder().encode(library)
        )

        XCTAssertEqual(edited.hotkey, hotkey)
        XCTAssertEqual(decoded.items.first?.hotkey, hotkey)
    }
}
