// Regression coverage for issue #224: TeXstudio rejects keyboard text
// containing more than one UTF-16 unit, including restored VNI text such as A4.

import CoreGraphics
import XCTest
@testable import PHTV

final class TeXstudioUnicodeEventTests: XCTestCase {
    private typealias EventPair = (down: CGEvent, up: CGEvent)

    private func eventPairs(
        for units: [UInt16],
        bundleId: String?
    ) throws -> [EventPair] {
        let source = try XCTUnwrap(CGEventSource(stateID: .privateState))
        var pairs: [EventPair] = []
        units.withUnsafeBufferPointer { chars in
            PHTVKeyEventSenderService.forEachUnicodeEventPair(
                chars: chars,
                source: source,
                bundleId: bundleId
            ) { down, up in
                pairs.append((down, up))
            }
        }
        return pairs
    }

    private func payload(of event: CGEvent) -> [UInt16] {
        var length = 0
        var units = [UInt16](repeating: 0, count: 256)
        event.keyboardGetUnicodeString(
            maxStringLength: units.count,
            actualStringLength: &length,
            unicodeString: &units
        )
        return Array(units.prefix(length))
    }

    // Match the editor's relevant input constraint. Reading CGEvent payloads
    // here exercises the actual events, not just a proposed chunk-size policy.
    private func textAcceptedByTeXstudio(_ pairs: [EventPair]) -> String {
        let acceptedUnits = pairs.compactMap { pair -> UInt16? in
            let units = payload(of: pair.down)
            return units.count == 1 ? units[0] : nil
        }
        return String(decoding: acceptedUnits, as: UTF16.self)
    }

    func testTeXstudioReceivesCompleteRestoredWordsAndMacroText() throws {
        let outputs = [
            "A4", "a1", "A2", "a3", "A5",
            "WINDOW", "terminal", "tiếng Việt", "\\alpha + \\beta"
        ]
        for text in outputs {
            let pairs = try eventPairs(for: Array(text.utf16), bundleId: "texstudio")
            XCTAssertEqual(textAcceptedByTeXstudio(pairs), text, text)
            XCTAssertEqual(pairs.flatMap { payload(of: $0.down) }, Array(text.utf16), text)
        }
    }

    func testCancellingAToneAndTypingTheNextWordPreservesEarlierText() throws {
        var document = "prefix Ã"
        document.removeLast() // The engine replaces only the currently marked A.
        document += textAcceptedByTeXstudio(
            try eventPairs(for: Array("A4".utf16), bundleId: "texstudio")
        )
        XCTAssertEqual(document, "prefix A4")

        document += " a"
        document.removeLast()
        document += textAcceptedByTeXstudio(
            try eventPairs(for: Array("á".utf16), bundleId: "texstudio")
        )
        XCTAssertEqual(document, "prefix A4 á")
    }

    func testTeXstudioBundleMatchingHandlesCaseAndSurroundingWhitespace() throws {
        for bundleId in ["texstudio", "TeXstudio", " TEXSTUDIO\n"] {
            let pairs = try eventPairs(for: Array("A4".utf16), bundleId: bundleId)
            XCTAssertEqual(textAcceptedByTeXstudio(pairs), "A4", bundleId)
            XCTAssertEqual(pairs.count, 2, bundleId)
        }
    }

    func testOtherEditorsAndQtApplicationsKeepBatchedUnicodeEvents() throws {
        let units = Array("A4 tiếng Việt".utf16)
        let otherTargets: [String?] = [
            "com.apple.TextEdit", "org.qt-project.qtcreator", "org.lyx.lyx",
            "texstudio.helper", "org.example.texstudio", "", nil
        ]
        for bundleId in otherTargets {
            let pairs = try eventPairs(for: units, bundleId: bundleId)
            XCTAssertEqual(pairs.count, 1, bundleId ?? "nil")
            let pair = try XCTUnwrap(pairs.first)
            XCTAssertEqual(payload(of: pair.down), units, bundleId ?? "nil")
            XCTAssertEqual(payload(of: pair.up), units, bundleId ?? "nil")
        }
    }

    func testEachUnicodeKeyDownHasAnEquivalentMarkedKeyUp() throws {
        let pairs = try eventPairs(for: Array("A4 ế".utf16), bundleId: "texstudio")
        XCTAssertFalse(pairs.isEmpty)
        for pair in pairs {
            XCTAssertEqual(pair.down.type, .keyDown)
            XCTAssertEqual(pair.up.type, .keyUp)
            XCTAssertEqual(payload(of: pair.down).count, 1)
            XCTAssertEqual(payload(of: pair.up), payload(of: pair.down))
            XCTAssertEqual(pair.up.flags, pair.down.flags)
            for event in [pair.down, pair.up] {
                XCTAssertEqual(event.getIntegerValueField(.eventSourceUserData), EventSourceMarker.phtv)
                XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), 0)
                XCTAssertTrue(event.flags.contains(.maskNonCoalesced))
                XCTAssertFalse(event.flags.contains(.maskSecondaryFn))
            }
        }
    }

    func testCombiningMarksRetainTheirUTF16UnitsAndSyncLengths() throws {
        let units: [UInt16] = [0x0061, 0x0303, 0x0041, 0x0301]
        let pairs = try eventPairs(for: units, bundleId: "texstudio")
        XCTAssertEqual(pairs.count, units.count)
        XCTAssertEqual(pairs.flatMap { payload(of: $0.down) }, units)
        XCTAssertEqual(pairs.flatMap { payload(of: $0.up) }, units)
        XCTAssertEqual(Array(textAcceptedByTeXstudio(pairs).utf16), units)
    }

    func testSupplementaryScalarsRemainValidUTF16InsideIndividualEvents() throws {
        let fixtures: [(text: String, eventText: [String])] = [
            ("A😀4", ["A", "😀", "4"]),
            ("😀𝄞", ["😀", "𝄞"])
        ]
        for fixture in fixtures {
            let units = Array(fixture.text.utf16)
            let pairs = try eventPairs(for: units, bundleId: "texstudio")
            XCTAssertEqual(pairs.flatMap { payload(of: $0.down) }, units)
            XCTAssertEqual(pairs.flatMap { payload(of: $0.up) }, units)
            // A high/low surrogate pair must reach the receiver together.
            // This preserves the scalar without promising QEditor accepts it.
            XCTAssertEqual(
                pairs.map { String(decoding: payload(of: $0.down), as: UTF16.self) },
                fixture.eventText
            )
            XCTAssertEqual(
                pairs.map { String(decoding: payload(of: $0.up), as: UTF16.self) },
                fixture.eventText
            )
        }
    }

    func testEmptyUnicodeOutputEmitsNoEvents() throws {
        let targets: [String?] = ["texstudio", "com.apple.TextEdit", nil]
        for bundleId in targets {
            XCTAssertTrue(try eventPairs(for: [], bundleId: bundleId).isEmpty)
        }
    }
}
