//
//  ClipboardSavedLibraryTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
import AppKit
import Carbon
@testable import PHTV

final class ClipboardSavedLibraryTests: XCTestCase {
    func testLibraryRoundTripsThroughJSON() throws {
        var library = ClipboardSavedLibrary()
        let group = try library.addGroup(named: "Công việc")
        _ = try library.saveItem(
            title: "Địa chỉ công ty",
            content: "123 Nguyễn Huệ",
            groupID: group.id
        )

        let data = try JSONEncoder().encode(library)
        let decoded = try JSONDecoder().decode(ClipboardSavedLibrary.self, from: data)

        XCTAssertEqual(decoded, library)
        XCTAssertEqual(decoded.version, ClipboardSavedLibrary.currentVersion)
    }

    func testDeletingGroupMovesItemsToUngroupedInsteadOfDeletingThem() throws {
        var library = ClipboardSavedLibrary()
        let group = try library.addGroup(named: "Tài khoản thử nghiệm")
        let item = try library.saveItem(
            title: "Email thử nghiệm",
            content: "tester@example.com",
            groupID: group.id
        )

        try library.removeGroup(id: group.id)

        XCTAssertTrue(library.groups.isEmpty)
        XCTAssertEqual(library.items.count, 1)
        XCTAssertEqual(library.items.first?.id, item.id)
        XCTAssertNil(library.items.first?.groupID)
    }

    func testGroupNamesAreTrimmedAndComparedWithoutCaseOrDiacritics() throws {
        var library = ClipboardSavedLibrary()
        let group = try library.addGroup(named: "  Công việc  ")

        XCTAssertEqual(group.name, "Công việc")
        XCTAssertThrowsError(try library.addGroup(named: "cong viec")) { error in
            XCTAssertEqual(error as? ClipboardSavedLibraryError, .duplicateGroupName)
        }
    }

    func testSavedItemRejectsEmptyTitleAndContent() throws {
        var library = ClipboardSavedLibrary()

        XCTAssertThrowsError(
            try library.saveItem(title: "   ", content: "Nội dung", groupID: nil)
        ) { error in
            XCTAssertEqual(error as? ClipboardSavedLibraryError, .emptyTitle)
        }
        XCTAssertThrowsError(
            try library.saveItem(title: "Tên", content: "\n  ", groupID: nil)
        ) { error in
            XCTAssertEqual(error as? ClipboardSavedLibraryError, .emptyContent)
        }
    }

    func testSearchMatchesTitleContentAndGroupName() throws {
        var library = ClipboardSavedLibrary()
        let work = try library.addGroup(named: "Công việc")
        let address = try library.saveItem(
            title: "Địa chỉ",
            content: "123 Nguyễn Huệ",
            groupID: work.id
        )
        let greeting = try library.saveItem(
            title: "Lời chào",
            content: "Xin chào các bạn",
            groupID: nil
        )

        XCTAssertEqual(library.matchingItems(searchText: "địa").map(\.id), [address.id])
        XCTAssertEqual(library.matchingItems(searchText: "xin chào").map(\.id), [greeting.id])
        XCTAssertEqual(library.matchingItems(searchText: "công việc").map(\.id), [address.id])
    }

    func testEditingItemPreservesIdentityAndCreationDate() throws {
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        var library = ClipboardSavedLibrary()
        let item = try library.saveItem(
            title: "Ban đầu",
            content: "A",
            groupID: nil,
            now: createdAt
        )

        let edited = try library.saveItem(
            id: item.id,
            title: "Đã sửa",
            content: "B",
            groupID: nil,
            now: updatedAt
        )

        XCTAssertEqual(edited.id, item.id)
        XCTAssertEqual(edited.createdAt, createdAt)
        XCTAssertEqual(edited.updatedAt, updatedAt)
        XCTAssertEqual(library.items.count, 1)
    }

    @MainActor
    func testClipboardPanelCommandNumberShortcutsSelectMatchingSection() throws {
        let captureView = ClipboardSectionShortcutCaptureView(frame: .zero)
        var selections: [ClipboardPanelSection] = []
        captureView.onSelect = { selections.append($0) }

        XCTAssertTrue(captureView.performKeyEquivalent(with: try keyEvent(kVK_ANSI_1)))
        XCTAssertTrue(captureView.performKeyEquivalent(with: try keyEvent(kVK_ANSI_2)))
        XCTAssertEqual(selections, [.history, .saved])
    }

    @MainActor
    func testClipboardPanelSectionShortcutsIgnoreExtraModifiersAndEditingState() throws {
        let captureView = ClipboardSectionShortcutCaptureView(frame: .zero)
        var selection: ClipboardPanelSection?
        captureView.onSelect = { selection = $0 }

        XCTAssertFalse(
            captureView.performKeyEquivalent(
                with: try keyEvent(kVK_ANSI_1, modifiers: [.command, .shift])
            )
        )
        XCTAssertNil(selection)

        captureView.isEnabled = false
        XCTAssertFalse(captureView.performKeyEquivalent(with: try keyEvent(kVK_ANSI_2)))
        XCTAssertNil(selection)
    }

    @MainActor
    private func keyEvent(
        _ keyCode: Int,
        modifiers: NSEvent.ModifierFlags = .command
    ) throws -> NSEvent {
        try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: UInt16(keyCode)
            )
        )
    }
}
