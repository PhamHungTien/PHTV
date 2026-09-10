import CoreGraphics
import XCTest
@testable import PHTV

final class TextOutputEncodingTests: XCTestCase {
    private let acuteA = EngineBitMask.charCode | UInt32(0x2061)

    private func pure(_ text: String) -> [UInt32] {
        text.unicodeScalars.map { $0.value | EngineBitMask.pureCharacter }
    }

    private func chunks(
        _ items: [UInt32], codeTable: Int32 = 3, reversed: Bool = false,
        limit: Int = 16, offset: Int = 0
    ) -> [PHTVTextOutputEncoder.Chunk] {
        var result: [PHTVTextOutputEncoder.Chunk] = []
        var cursor = offset
        while cursor < items.count {
            let chunk = PHTVTextOutputEncoder.nextChunk(
                from: items, sourceCount: items.count, sourceOffset: cursor,
                reversed: reversed, codeTable: codeTable, maximumUTF16Count: limit
            )
            XCTAssertGreaterThan(chunk.nextSourceOffset, cursor)
            guard chunk.nextSourceOffset > cursor else { break }
            cursor = chunk.nextSourceOffset
            result.append(chunk)
        }
        return result
    }

    func testCompositeMarkIsPreservedAtEveryChunkBoundary() {
        for prefix in [0, 14, 15, 16, 17, 30, 31, 32, 33, 63] {
            let items = pure(String(repeating: "x", count: prefix)) + [acuteA] + pure("b")
            let output = chunks(items)
            XCTAssertEqual(output.flatMap(\.units), Array((String(repeating: "x", count: prefix) + "a\u{0301}b").utf16))
            XCTAssertTrue(output.allSatisfy { $0.units.count <= 16 })
            XCTAssertEqual(output.flatMap(\.syncKeyLengths), Array(repeating: 1, count: prefix) + [2, 1])
        }
    }

    func testReversedEngineOutputConsumesEverySourceItemOnceAcrossManyChunks() {
        let expectedItems = Array(repeating: acuteA, count: 30) + pure("xyz")
        let output = chunks(Array(expectedItems.reversed()), reversed: true)
        XCTAssertEqual(output.flatMap(\.units), Array((String(repeating: "a\u{0301}", count: 30) + "xyz").utf16))
        XCTAssertEqual(output.last?.nextSourceOffset, expectedItems.count)
        XCTAssertEqual(output.flatMap(\.syncKeyLengths), Array(repeating: 2, count: 30) + [1, 1, 1])
    }

    func testExplicitSourceOffsetIsInItemsNotUTF16Units() {
        let output = chunks([acuteA, acuteA] + pure("z"), offset: 1)
        XCTAssertEqual(output.flatMap(\.units), Array("a\u{0301}z".utf16))
    }

    func testSupplementaryScalarsAndZWJSequencesRoundTripOnEveryCodeTable() {
        let text = "đ🙂👩🏽‍💻𠀀"
        for table: Int32 in [0, 1, 2, 3, 4] {
            for limit in [1, 2, 3, 16] {
                let output = chunks(pure(text), codeTable: table, limit: limit)
                XCTAssertEqual(output.flatMap(\.units), Array(text.utf16))
                for chunk in output {
                    // Each chunk must be valid Unicode independently, even if
                    // a composed sequence spans adjacent transport events.
                    XCTAssertEqual(Array(String(decoding: chunk.units, as: UTF16.self).utf16), chunk.units)
                }
            }
        }
    }

    func testLegacyDoubleByteOutputAndSyncKeyLengthsArePreserved() {
        let data = EngineBitMask.charCode | UInt32(0x4561)
        for table: Int32 in [1, 2, 4] {
            let output = chunks(Array(repeating: data, count: 17), codeTable: table)
            XCTAssertEqual(output.flatMap(\.units), Array(repeating: [UInt16(0x61), 0x45], count: 17).flatMap { $0 })
            XCTAssertEqual(output.flatMap(\.syncKeyLengths), table == 2 ? Array(repeating: 2, count: 17) : [])
        }
    }

    func testInvalidScalarIsSkippedWithoutBlockingFollowingItems() {
        XCTAssertNil(PHTVTextOutputEncoder.scalar(0xD800))
        XCTAssertNil(PHTVTextOutputEncoder.scalar(0x110000))
        let output = chunks([EngineBitMask.pureCharacter | 0xD800] + pure("ok"))
        XCTAssertEqual(output.flatMap(\.units), Array("ok".utf16))
        XCTAssertEqual(output.last?.nextSourceOffset, 3)
    }

    func testChunkCountAndOffsetsAreClamped() {
        let output = PHTVTextOutputEncoder.nextChunk(
            from: pure("abc"), sourceCount: Int.max, sourceOffset: -100,
            reversed: false, codeTable: 0, maximumUTF16Count: 0
        )
        XCTAssertEqual(output.units, Array("a".utf16))
        XCTAssertEqual(output.nextSourceOffset, 1)
        let empty = PHTVTextOutputEncoder.nextChunk(
            from: [], sourceCount: 100, sourceOffset: 100, reversed: true, codeTable: 0
        )
        XCTAssertTrue(empty.units.isEmpty)
        XCTAssertEqual(empty.nextSourceOffset, 0)
    }

    func testTransportNeverSplitsSurrogatePairs() {
        let units = Array("x🙂y🙂".utf16)
        units.withUnsafeBufferPointer { buffer in
            for limit in [1, 2, 3, 4, 16] {
                var offset = 0
                var emitted: [UInt16] = []
                while offset < buffer.count {
                    let count = PHTVTextOutputEncoder.unicodeChunkLength(in: buffer, offset: offset, maximumCount: limit)
                    let fragment = Array(buffer[offset..<(offset + count)])
                    XCTAssertEqual(Array(String(decoding: fragment, as: UTF16.self).utf16), fragment)
                    emitted += fragment
                    offset += count
                }
                XCTAssertEqual(emitted, units)
            }
        }
    }
}

final class AXReplacementRangeTests: XCTestCase {
    func testNFCAndNFDReplaceTheWholeAccentedCharacter() {
        for text in ["á", "a\u{0301}", "a\u{0302}\u{0301}", "prefix a\u{0301}"] {
            let source = text as NSString
            let start = PHTVAccessibilityService.calculateDeleteStartForAX(text, caretLocation: source.length, backspaceCount: 1)
            let output = source.replacingCharacters(in: NSRange(location: start, length: source.length - start), with: "à")
            XCTAssertEqual(output, text.hasPrefix("prefix ") ? "prefix à" : "à")
        }
    }

    func testMultipleLogicalCharactersIncludeSurrogatesAndCombiningSequences() {
        let text = "prefix 🙂a\u{0301}"
        let start = PHTVAccessibilityService.calculateDeleteStartForAX(
            text, caretLocation: (text as NSString).length, backspaceCount: 2
        )
        XCTAssertEqual(start, ("prefix " as NSString).length)
    }

    func testCaretInMiddleOfTextPreservesTheSuffix() {
        let source = "a\u{0301}suffix" as NSString
        let start = PHTVAccessibilityService.calculateDeleteStartForAX(source as String, caretLocation: 2, backspaceCount: 1)
        XCTAssertEqual(source.replacingCharacters(in: NSRange(location: start, length: 2 - start), with: "à"), "àsuffix")
    }

    func testInvalidOffsetsAndEmptyInputAreSafe() {
        XCTAssertEqual(PHTVAccessibilityService.calculateDeleteStartForAX(nil, caretLocation: 100, backspaceCount: 1), 0)
        XCTAssertEqual(PHTVAccessibilityService.calculateDeleteStartForAX("", caretLocation: 100, backspaceCount: 1), 0)
        XCTAssertEqual(PHTVAccessibilityService.calculateDeleteStartForAX("abc", caretLocation: -10, backspaceCount: 1), 0)
        XCTAssertEqual(PHTVAccessibilityService.calculateDeleteStartForAX("abc", caretLocation: 100, backspaceCount: 1), 2)
        XCTAssertEqual(PHTVAccessibilityService.calculateDeleteStartForAX("abc", caretLocation: 2, backspaceCount: -1), 2)
        XCTAssertEqual(PHTVAccessibilityService.calculateDeleteStartForAX("abc", caretLocation: 2, backspaceCount: Int.max), 0)
    }
}
