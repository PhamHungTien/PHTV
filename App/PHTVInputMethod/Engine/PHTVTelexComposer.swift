import Foundation

struct PHTVTelexComposer {
    func compose(_ rawText: String) -> String {
        guard !rawText.isEmpty else { return "" }

        var scalars = Array(rawText.unicodeScalars)
        var tone: PHTVTelexTone?

        if let toneIndex = scalars.lastIndex(where: { PHTVTelexTone(rawValue: Character($0).lowercased()) != nil }) {
            let marker = Character(scalars[toneIndex]).lowercased()
            tone = PHTVTelexTone(rawValue: marker)
            scalars.remove(at: toneIndex)
        }

        let base = applyTelexShape(to: String(String.UnicodeScalarView(scalars)))
        guard let tone, tone != .clear else { return base }
        return apply(tone: tone, to: base)
    }

    private func applyTelexShape(to text: String) -> String {
        var output: [Character] = []
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            let nextIndex = text.index(after: index)

            if nextIndex < text.endIndex {
                let nextCharacter = text[nextIndex]
                if let shaped = shapedPair(character, nextCharacter) {
                    output.append(shaped)
                    index = text.index(after: nextIndex)
                    continue
                }
            }

            output.append(standaloneShape(character))
            index = nextIndex
        }

        return String(output)
    }

    private func shapedPair(_ first: Character, _ second: Character) -> Character? {
        let lowerPair = first.lowercased() + second.lowercased()
        let shaped: Character?

        switch lowerPair {
        case "aa": shaped = "â"
        case "aw": shaped = "ă"
        case "dd": shaped = "đ"
        case "ee": shaped = "ê"
        case "oo": shaped = "ô"
        case "ow": shaped = "ơ"
        case "uw": shaped = "ư"
        default: shaped = nil
        }

        guard let shaped else { return nil }
        return first.isUppercase ? Character(shaped.uppercased()) : shaped
    }

    private func standaloneShape(_ character: Character) -> Character {
        switch character.lowercased() {
        case "w":
            return character.isUppercase ? "Ư" : "ư"
        default:
            return character
        }
    }

    private func apply(tone: PHTVTelexTone, to text: String) -> String {
        var characters = Array(text)
        guard let vowelIndex = characters.lastIndex(where: { PHTVVietnameseToneTable.contains($0) }) else {
            return text
        }

        characters[vowelIndex] = PHTVVietnameseToneTable.apply(tone: tone, to: characters[vowelIndex])
        return String(characters)
    }
}

private enum PHTVTelexTone: String {
    case acute = "s"
    case grave = "f"
    case hook = "r"
    case tilde = "x"
    case dot = "j"
    case clear = "z"
}

private enum PHTVVietnameseToneTable {
    private static let table: [Character: [PHTVTelexTone: Character]] = [
        "a": [.acute: "á", .grave: "à", .hook: "ả", .tilde: "ã", .dot: "ạ"],
        "ă": [.acute: "ắ", .grave: "ằ", .hook: "ẳ", .tilde: "ẵ", .dot: "ặ"],
        "â": [.acute: "ấ", .grave: "ầ", .hook: "ẩ", .tilde: "ẫ", .dot: "ậ"],
        "e": [.acute: "é", .grave: "è", .hook: "ẻ", .tilde: "ẽ", .dot: "ẹ"],
        "ê": [.acute: "ế", .grave: "ề", .hook: "ể", .tilde: "ễ", .dot: "ệ"],
        "i": [.acute: "í", .grave: "ì", .hook: "ỉ", .tilde: "ĩ", .dot: "ị"],
        "o": [.acute: "ó", .grave: "ò", .hook: "ỏ", .tilde: "õ", .dot: "ọ"],
        "ô": [.acute: "ố", .grave: "ồ", .hook: "ổ", .tilde: "ỗ", .dot: "ộ"],
        "ơ": [.acute: "ớ", .grave: "ờ", .hook: "ở", .tilde: "ỡ", .dot: "ợ"],
        "u": [.acute: "ú", .grave: "ù", .hook: "ủ", .tilde: "ũ", .dot: "ụ"],
        "ư": [.acute: "ứ", .grave: "ừ", .hook: "ử", .tilde: "ữ", .dot: "ự"],
        "y": [.acute: "ý", .grave: "ỳ", .hook: "ỷ", .tilde: "ỹ", .dot: "ỵ"],
        "A": [.acute: "Á", .grave: "À", .hook: "Ả", .tilde: "Ã", .dot: "Ạ"],
        "Ă": [.acute: "Ắ", .grave: "Ằ", .hook: "Ẳ", .tilde: "Ẵ", .dot: "Ặ"],
        "Â": [.acute: "Ấ", .grave: "Ầ", .hook: "Ẩ", .tilde: "Ẫ", .dot: "Ậ"],
        "E": [.acute: "É", .grave: "È", .hook: "Ẻ", .tilde: "Ẽ", .dot: "Ẹ"],
        "Ê": [.acute: "Ế", .grave: "Ề", .hook: "Ể", .tilde: "Ễ", .dot: "Ệ"],
        "I": [.acute: "Í", .grave: "Ì", .hook: "Ỉ", .tilde: "Ĩ", .dot: "Ị"],
        "O": [.acute: "Ó", .grave: "Ò", .hook: "Ỏ", .tilde: "Õ", .dot: "Ọ"],
        "Ô": [.acute: "Ố", .grave: "Ồ", .hook: "Ổ", .tilde: "Ỗ", .dot: "Ộ"],
        "Ơ": [.acute: "Ớ", .grave: "Ờ", .hook: "Ở", .tilde: "Ỡ", .dot: "Ợ"],
        "U": [.acute: "Ú", .grave: "Ù", .hook: "Ủ", .tilde: "Ũ", .dot: "Ụ"],
        "Ư": [.acute: "Ứ", .grave: "Ừ", .hook: "Ử", .tilde: "Ữ", .dot: "Ự"],
        "Y": [.acute: "Ý", .grave: "Ỳ", .hook: "Ỷ", .tilde: "Ỹ", .dot: "Ỵ"],
    ]

    static func contains(_ character: Character) -> Bool {
        table[character] != nil
    }

    static func apply(tone: PHTVTelexTone, to character: Character) -> Character {
        table[character]?[tone] ?? character
    }
}
