import Foundation

struct PHTVOutputTranscoder {
    func transcode(_ text: String, to encoding: PHTVOutputEncoding) -> String {
        guard encoding != .unicode, !text.isEmpty else {
            return text.precomposedStringWithCanonicalMapping
        }

        let source = Array(text.precomposedStringWithCanonicalMapping.utf16)
        var output: [UInt16] = []
        output.reserveCapacity(source.count * 2)

        for character in source {
            guard let (keyCode, variantIndex) = PHTVInputCodeTableLookup.findSourceKey(
                codeTable: Int32(PHTVOutputEncoding.unicode.rawValue),
                character: character
            ),
            let targetCharacter = PHTVInputCodeTableLookup.characterForKey(
                codeTable: Int32(encoding.rawValue),
                keyCode: keyCode,
                variantIndex: variantIndex
            ) else {
                output.append(character)
                continue
            }

            append(targetCharacter, for: encoding, to: &output)
        }

        return String(decoding: output, as: UTF16.self)
    }

    private func append(_ character: UInt16, for encoding: PHTVOutputEncoding, to output: inout [UInt16]) {
        switch encoding {
        case .unicode:
            output.append(character)

        case .tcvn3:
            output.append(character)

        case .vniWindows, .cp1258:
            let lowByte = character & 0x00FF
            let highByte = (character >> 8) & 0x00FF
            output.append(lowByte)
            if highByte > 32 {
                output.append(highByte)
            }

        case .unicodeComposite:
            let markIndex = Int(character >> 13)
            if markIndex > 0 {
                output.append(character & 0x1FFF)
                output.append(PHTVUnicodeCompositeMark.mark(at: markIndex - 1))
            } else {
                output.append(character)
            }
        }
    }
}

private enum PHTVUnicodeCompositeMark {
    private static let marks: [UInt16] = [0x0301, 0x0300, 0x0309, 0x0303, 0x0323]

    static func mark(at index: Int) -> UInt16 {
        guard marks.indices.contains(index) else { return 0 }
        return marks[index]
    }
}
