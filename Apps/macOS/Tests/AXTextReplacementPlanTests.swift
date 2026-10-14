import XCTest
@testable import PHTV

final class AXTextReplacementPlanTests: XCTestCase {
    func testMidQueryToneEditPreservesSuffixAndCaret() throws {
        let edit = try XCTUnwrap(AXTextReplacementPlan.make(value: "tien viet", selection: NSRange(location: 4, length: 0), backspaceCount: 3, insertion: "iến"))
        XCTAssertEqual(edit.value, "tiến viet")
        XCTAssertEqual(edit.caret, 4)
    }

    func testDeletionDoesNotSplitCombiningMarksOrEmoji() throws {
        for token in ["a\u{0306}\u{0301}", "👨‍👩‍👧‍👦", "🇻🇳", "ắ"] {
            let original = "x" + token + " suffix"
            let caret = ("x" + token as NSString).length
            let edit = try XCTUnwrap(AXTextReplacementPlan.make(value: original, selection: NSRange(location: caret, length: 0), backspaceCount: 1, insertion: "à"))
            XCTAssertEqual(edit.value, "xà suffix")
            XCTAssertEqual(edit.caret, 2)
        }
    }

    func testHighlightedMiddleIsReplacedWithoutDeletingPrefix() throws {
        let edit = try XCTUnwrap(AXTextReplacementPlan.make(value: "xin chao ban", selection: NSRange(location: 4, length: 4), backspaceCount: 4, insertion: "chào"))
        XCTAssertEqual(edit.value, "xin chào ban")
        XCTAssertEqual(edit.caret, 8)
    }

    func testAutocompleteSuffixAndTypedCharacterAreReplacedTogether() throws {
        let edit = try XCTUnwrap(AXTextReplacementPlan.make(value: "Safari", selection: NSRange(location: 2, length: 4), backspaceCount: 1, insertion: "á"))
        XCTAssertEqual(edit.value, "Sá")
        XCTAssertEqual(edit.caret, 2)
    }

    func testUnknownOrStaleSelectionCannotRewriteField() {
        for selection: NSRange? in [nil, NSRange(location: NSNotFound, length: 0), NSRange(location: 1, length: Int.max), NSRange(location: 4, length: 0)] {
            XCTAssertNil(AXTextReplacementPlan.make(value: "abc", selection: selection, backspaceCount: 1, insertion: "á"))
        }
    }
}
