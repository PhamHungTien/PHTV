import XCTest
@testable import PHTV

final class EmojiPickerKeyboardNavigationTests: XCTestCase {

    func testArrowDownFromSearchFocusesFirstEmoji() {
        let navigator = EmojiPickerKeyboardNavigator(itemCount: 14, columnCount: 7)

        XCTAssertEqual(
            navigator.action(for: .enterGrid, from: .search),
            .focus(.grid(index: 0))
        )
    }

    func testTabMovesAcrossGrid() {
        let navigator = EmojiPickerKeyboardNavigator(itemCount: 14, columnCount: 7)

        XCTAssertEqual(
            navigator.action(for: .moveNext, from: .grid(index: 4)),
            .focus(.grid(index: 5))
        )
    }

    func testShiftTabFromFirstEmojiReturnsToSearch() {
        let navigator = EmojiPickerKeyboardNavigator(itemCount: 14, columnCount: 7)

        XCTAssertEqual(
            navigator.action(for: .movePrevious, from: .grid(index: 0)),
            .focus(.search)
        )
    }

    func testArrowUpFromFirstRowReturnsToSearch() {
        let navigator = EmojiPickerKeyboardNavigator(itemCount: 14, columnCount: 7)

        XCTAssertEqual(
            navigator.action(for: .moveUp, from: .grid(index: 3)),
            .focus(.search)
        )
    }

    func testArrowDownKeepsColumnWhenRowExists() {
        let navigator = EmojiPickerKeyboardNavigator(itemCount: 14, columnCount: 7)

        XCTAssertEqual(
            navigator.action(for: .moveDown, from: .grid(index: 2)),
            .focus(.grid(index: 9))
        )
    }

    func testArrowDownNoopsWhenNoCellBelow() {
        let navigator = EmojiPickerKeyboardNavigator(itemCount: 10, columnCount: 7)

        XCTAssertEqual(
            navigator.action(for: .moveDown, from: .grid(index: 6)),
            .noop
        )
    }

    func testActivateSelectionReturnsFocusedIndex() {
        let navigator = EmojiPickerKeyboardNavigator(itemCount: 14, columnCount: 7)

        XCTAssertEqual(
            navigator.action(for: .activateSelection, from: .grid(index: 8)),
            .activate(index: 8)
        )
    }
}
