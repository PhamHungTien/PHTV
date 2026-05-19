import Foundation

struct PHTVVietnameseComposer {
    func compose(_ rawText: String, style: PHTVInputStyle) -> String {
        guard !rawText.isEmpty else { return "" }

        let normalizedText = rawText.precomposedStringWithCanonicalMapping
        switch style {
        case .telex, .simpleTelex1, .simpleTelex2:
            return composeTelex(normalizedText, style: style)
        case .vni:
            return composeVNI(normalizedText)
        }
    }

    private func composeTelex(_ rawText: String, style: PHTVInputStyle) -> String {
        let characters = Array(rawText)
        var output: [Character] = []
        var activeTone: PHTVTone? = nil

        for char in characters {
            if let tone = PHTVTelexMarker.tone(for: char) {
                let hasVowelBefore = output.contains {
                    PHTVVietnameseToneTable.contains($0) || $0.lowercased() == "w"
                }
                if hasVowelBefore {
                    if let current = activeTone, current == tone {
                        activeTone = nil
                        if tone != .clear {
                            output.append(char)
                        }
                    } else {
                        activeTone = tone
                    }
                    continue
                }
            }
            output.append(char)
        }

        let base = applyTelexShapes(to: output, style: style)
        guard let activeTone, activeTone != .clear else { return String(base) }
        return apply(tone: activeTone, to: base)
    }

    private func composeVNI(_ rawText: String) -> String {
        let characters = Array(rawText)
        var output: [Character] = []
        var activeTone: PHTVTone? = nil

        for char in characters {
            if let tone = PHTVVNIMarker.tone(for: char) {
                let hasVowelBefore = output.contains {
                    PHTVVietnameseToneTable.contains($0)
                }
                if hasVowelBefore {
                    if let current = activeTone, current == tone {
                        activeTone = nil
                        if tone != .clear {
                            output.append(char)
                        }
                    } else {
                        activeTone = tone
                    }
                    continue
                }
            }
            output.append(char)
        }

        let base = applyVNIShapes(to: output)
        guard let activeTone, activeTone != .clear else { return String(base) }
        return apply(tone: activeTone, to: base)
    }

    private func applyTelexShapes(to characters: [Character], style: PHTVInputStyle) -> [Character] {
        var output: [Character] = []
        output.reserveCapacity(characters.count)

        for (index, character) in characters.enumerated() {
            let lower = character.lowercased()
            switch lower {
            case "a":
                if replaceLast(in: &output, matching: "a", with: character.isUppercase ? "Â" : "â") {
                    continue
                }
            case "d":
                if replaceLast(in: &output, matching: "d", with: character.isUppercase ? "Đ" : "đ") {
                    continue
                }
            case "e":
                if replaceLast(in: &output, matching: "e", with: character.isUppercase ? "Ê" : "ê") {
                    continue
                }
            case "o":
                if replaceLast(in: &output, matching: "o", with: character.isUppercase ? "Ô" : "ô") {
                    continue
                }
            case "w":
                let isConsecutiveW = index > 0 && characters[index - 1].lowercased() == "w"
                if isConsecutiveW {
                    let prevWIndex = index - 1
                    let hasVowelBeforePrevW = prevWIndex > 0 && ["u", "o", "a"].contains(characters[prevWIndex - 1].lowercased())
                    
                    if hasVowelBeforePrevW {
                        output.append(character.isUppercase ? "W" : "w")
                    } else {
                        if !output.isEmpty && (output.last == "ư" || output.last == "Ư") {
                            output[output.count - 1] = character.isUppercase ? "W" : "w"
                        } else {
                            output.append(character.isUppercase ? "W" : "w")
                        }
                    }
                    continue
                }

                if applyTelexW(to: &output, uppercase: character.isUppercase, style: style) {
                    continue
                }
            default:
                break
            }

            output.append(character)
        }

        return output
    }

    private func applyVNIShapes(to characters: [Character]) -> [Character] {
        var output: [Character] = []
        output.reserveCapacity(characters.count)

        for character in characters {
            switch character {
            case "6":
                if replaceLastVowel(in: &output, using: ["a": "â", "A": "Â", "e": "ê", "E": "Ê", "o": "ô", "O": "Ô"]) {
                    continue
                }
            case "7":
                if replaceLastVowel(in: &output, using: ["o": "ơ", "O": "Ơ", "u": "ư", "U": "Ư"]) {
                    continue
                }
            case "8":
                if replaceLastVowel(in: &output, using: ["a": "ă", "A": "Ă"]) {
                    continue
                }
            case "9":
                if replaceLast(in: &output, matching: "d", with: "đ") || replaceLast(in: &output, matching: "D", with: "Đ") {
                    continue
                }
            default:
                break
            }

            output.append(character)
        }

        return output
    }

    private func applyTelexW(to output: inout [Character], uppercase: Bool, style: PHTVInputStyle) -> Bool {
        if output.count >= 2,
           output[output.count - 2].lowercased() == "u",
           output[output.count - 1].lowercased() == "o" {
            let upperPair = output[output.count - 2].isUppercase && output[output.count - 1].isUppercase
            output[output.count - 2] = upperPair ? "Ư" : "ư"
            output[output.count - 1] = upperPair ? "Ơ" : "ơ"
            return true
        }

        if replaceLastVowel(in: &output, using: [
            "a": "ă", "A": "Ă",
            "o": "ơ", "O": "Ơ",
            "u": "ư", "U": "Ư",
        ]) {
            return true
        }

        if style == .simpleTelex2 {
            output.append(uppercase ? "W" : "w")
        } else {
            output.append(uppercase ? "Ư" : "ư")
        }
        return true
    }

    private func replaceLast(in output: inout [Character], matching raw: Character, with shaped: Character) -> Bool {
        guard let index = output.lastIndex(where: { $0 == raw }) else { return false }
        output[index] = shaped
        return true
    }

    private func replaceLast(in output: inout [Character], matching rawLowercase: String, with shaped: Character) -> Bool {
        guard let index = output.lastIndex(where: { $0.lowercased() == rawLowercase }) else { return false }
        output[index] = output[index].isUppercase ? Character(shaped.uppercased()) : shaped
        return true
    }

    private func replaceLastVowel(in output: inout [Character], using map: [Character: Character]) -> Bool {
        for index in output.indices.reversed() {
            if let shaped = map[output[index]] {
                output[index] = shaped
                return true
            }
        }
        return false
    }

    private func apply(tone: PHTVTone, to characters: [Character]) -> String {
        var output = characters
        guard let vowelIndex = toneTargetIndex(in: output) else {
            return String(output)
        }

        output[vowelIndex] = PHTVVietnameseToneTable.apply(tone: tone, to: output[vowelIndex])
        return String(output)
    }

    private func toneTargetIndex(in characters: [Character]) -> Int? {
        let vowelRuns = vowelRuns(in: characters)
        guard let run = vowelRuns.last else { return nil }

        // Adjust active run to handle initial consonants "gi" and "qu" where
        // the "i" or "u" is part of the consonant, not the active vowel run.
        var activeRun = run
        if run.count > 1 {
            let firstIndex = run[0]
            let firstChar = characters[firstIndex].lowercased()
            if firstIndex > 0 {
                let prevChar = characters[firstIndex - 1].lowercased()
                if (firstChar == "i" && prevChar == "g") || (firstChar == "u" && prevChar == "q") {
                    activeRun = Array(run[1...])
                }
            }
        }

        // Scan right-to-left in the active run so that in diphthongs where both vowels carry a
        // shape mark (e.g. "ươ"), the rightmost marked base wins. This gives the
        // correct placement for "huowsng" → "hướng" (acute on ơ, not on ư).
        for index in activeRun.reversed() where PHTVVietnameseToneTable.isMarkedBase(characters[index]) {
            return index
        }

        let activeRunText = activeRun.map { characters[$0].lowercased() }.joined()
        if activeRunText.hasPrefix("oa") || activeRunText.hasPrefix("oe") || activeRunText.hasPrefix("uy") {
            return activeRun.count > 1 ? activeRun[1] : activeRun.first
        }

        return activeRun.first
    }

    private func vowelRuns(in characters: [Character]) -> [[Int]] {
        var runs: [[Int]] = []
        var currentRun: [Int] = []

        for (index, character) in characters.enumerated() {
            if PHTVVietnameseToneTable.contains(character) {
                currentRun.append(index)
            } else if !currentRun.isEmpty {
                runs.append(currentRun)
                currentRun.removeAll(keepingCapacity: true)
            }
        }

        if !currentRun.isEmpty {
            runs.append(currentRun)
        }

        return runs
    }
}

private enum PHTVTone {
    case acute
    case grave
    case hook
    case tilde
    case dot
    case clear
}

private enum PHTVTelexMarker {
    static func tone(for character: Character) -> PHTVTone? {
        switch character.lowercased() {
        case "s": return .acute
        case "f": return .grave
        case "r": return .hook
        case "x": return .tilde
        case "j": return .dot
        case "z": return .clear
        default: return nil
        }
    }
}

private enum PHTVVNIMarker {
    static func tone(for character: Character) -> PHTVTone? {
        switch character {
        case "1": return .acute
        case "2": return .grave
        case "3": return .hook
        case "4": return .tilde
        case "5": return .dot
        case "0": return .clear
        default: return nil
        }
    }
}

private enum PHTVVietnameseToneTable {
    private static let table: [Character: [PHTVTone: Character]] = [
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

    static func isMarkedBase(_ character: Character) -> Bool {
        switch character {
        case "ă", "â", "ê", "ô", "ơ", "ư", "Ă", "Â", "Ê", "Ô", "Ơ", "Ư":
            return true
        default:
            return false
        }
    }

    static func apply(tone: PHTVTone, to character: Character) -> Character {
        table[character]?[tone] ?? character
    }
}
