import Foundation

struct PHTVVietnameseComposer {
    func compose(_ rawText: String, style: PHTVInputStyle, autoRestore: Bool = true) -> String {
        guard !rawText.isEmpty else { return "" }

        let normalizedText = rawText.precomposedStringWithCanonicalMapping
        let composed: String
        switch style {
        case .telex, .simpleTelex1, .simpleTelex2:
            composed = composeTelex(normalizedText, style: style)
        case .vni:
            composed = composeVNI(normalizedText)
        }

        if autoRestore && !isVietnameseSyllablePossible(composed) {
            return rawText
        }
        return composed
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

        var base = applyTelexShapes(to: output, style: style)
        base = normalizeVowels(base)
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

        var base = applyVNIShapes(to: output)
        base = normalizeVowels(base)
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

    private func normalizeVowels(_ characters: [Character]) -> [Character] {
        var output = characters
        guard output.count >= 2 else { return output }

        for i in 0..<(output.count - 1) {
            let c1 = output[i]
            let c2 = output[i + 1]

            let decomp1 = PHTVVietnameseToneTable.decompose(c1)
            let decomp2 = PHTVVietnameseToneTable.decompose(c2)

            let base1 = decomp1.base
            let base2 = decomp2.base

            let isU1 = base1 == "u" || base1 == "U"
            let isUw1 = base1 == "ư" || base1 == "Ư"
            let isO2 = base2 == "o" || base2 == "O"
            let isOw2 = base2 == "ơ" || base2 == "Ơ"

            if (isU1 && isOw2) || (isUw1 && isO2) {
                let normBase1: Character = base1.isUppercase ? "Ư" : "ư"
                let normBase2: Character = base2.isUppercase ? "Ơ" : "ơ"

                let activeTone = decomp1.tone ?? decomp2.tone
                if let activeTone {
                    output[i] = normBase1
                    output[i + 1] = PHTVVietnameseToneTable.apply(tone: activeTone, to: normBase2)
                } else {
                    output[i] = normBase1
                    output[i + 1] = normBase2
                }
            }
        }
        return output
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

    private func isVietnameseSyllablePossible(_ word: String) -> Bool {
        // Empty string is not a syllable
        guard !word.isEmpty else { return true }
        
        // If the word contains non-letter characters (like digits or punctuation), it's not a standard Vietnamese syllable
        guard word.allSatisfy({ $0.isLetter }) else { return false }
        
        // Find all contiguous runs of vowels
        let vowels = Set("aàáảãạăằắẳẵặâầấẩẫậeèéẻẽẹêềếểễệiìíỉĩịoòóỏõọôồốổỗộơờớởỡợuùúủũụưừứửữựyỳýỷỹỵAÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬEÈÉẺẼẸÊỀẾỂỄỆIÌÍỈĨỊOÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢUÙÚỦŨỤƯỪỨỬỮỰYỲÝỶỸỴ")
        
        var vowelRuns: [Range<String.Index>] = []
        var inRun = false
        var runStart = word.startIndex
        
        for index in word.indices {
            let char = word[index]
            let isV = vowels.contains(char)
            if isV && !inRun {
                runStart = index
                inRun = true
            } else if !isV && inRun {
                vowelRuns.append(runStart..<index)
                inRun = false
            }
        }
        if inRun {
            vowelRuns.append(runStart..<word.endIndex)
        }
        
        // If there are no vowels, it's an in-progress consonant typing (like "str", "ngh"). We allow it.
        if vowelRuns.isEmpty {
            return true
        }
        
        // If there is more than 1 vowel run (e.g. "terminal", "microsoft"), it is 100% English/foreign
        if vowelRuns.count > 1 {
            return false
        }
        
        var vowelRange = vowelRuns[0]
        
        // Handle "gi" and "qu" where the first vowel of the run is actually part of the initial consonant
        if word.index(after: vowelRange.lowerBound) < vowelRange.upperBound {
            let firstVowelIndex = vowelRange.lowerBound
            let firstVowelChar = word[firstVowelIndex].lowercased()
            if firstVowelIndex > word.startIndex {
                let prevIndex = word.index(before: firstVowelIndex)
                let prevChar = word[prevIndex].lowercased()
                if (firstVowelChar == "i" && prevChar == "g") || (firstVowelChar == "u" && prevChar == "q") {
                    vowelRange = word.index(after: firstVowelIndex)..<vowelRange.upperBound
                }
            }
        }
        
        let vowelRun = String(word[vowelRange])
        let initialPart = String(word[..<vowelRange.lowerBound])
        let finalPart = String(word[vowelRange.upperBound...])
        
        let lowerInitial = initialPart.lowercased()
        let lowerFinal = finalPart.lowercased()
        
        // 1. Validate Initial Consonant
        let validInitials: Set<String> = [
            "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh",
            "l", "m", "n", "ng", "ngh", "nh", "p", "ph", "q", "qu", "r", "s",
            "t", "th", "tr", "v", "x"
        ]
        guard validInitials.contains(lowerInitial) else {
            return false
        }
        
        // 2. Validate Final Consonant
        let validFinals: Set<String> = [
            "", "c", "ch", "m", "n", "ng", "nh", "p", "t"
        ]
        guard validFinals.contains(lowerFinal) else {
            return false
        }
        
        // 3. Map Vowel Run to Base ASCII Vowel Run
        func toBaseVowel(_ char: Character) -> Character {
            let lower = char.lowercased()
            switch lower {
            case "a", "à", "á", "ả", "ã", "ạ", "ă", "ằ", "ắ", "ẳ", "ẵ", "ặ", "â", "ầ", "ấ", "ẩ", "ẫ", "ậ":
                return "a"
            case "e", "è", "é", "ẻ", "ẽ", "ẹ", "ê", "ề", "ế", "ể", "ễ", "ệ":
                return "e"
            case "i", "ì", "í", "ỉ", "ĩ", "ị":
                return "i"
            case "o", "ò", "ó", "ỏ", "õ", "ọ", "ô", "ồ", "ố", "ổ", "ỗ", "ộ", "ơ", "ờ", "ớ", "ở", "ỡ", "ợ":
                return "o"
            case "u", "ù", "ú", "ủ", "ũ", "ụ", "ư", "ừ", "ứ", "ử", "ữ", "ự":
                return "u"
            case "y", "ỳ", "ý", "ỷ", "ỹ", "ỵ":
                return "y"
            default:
                return Character(lower)
            }
        }
        
        let vowelRunBase = String(vowelRun.map { toBaseVowel($0) })
        
        let validBaseVowelRuns: Set<String> = [
            "a", "e", "i", "o", "u", "y", "ai", "ao", "au", "ay", "eo", "ia", "ie", "iu", "oa", "oe", "oi", "oo",
            "ua", "ue", "ui", "uo", "uu", "uy", "ye", "ieu", "yeu", "oai", "oay", "oao", "oeo", "uay", "uoi", "uou",
            "uya", "uye", "uyu"
        ]
        
        guard validBaseVowelRuns.contains(vowelRunBase) else {
            return false
        }
        
        // 4. Advanced Spelling Constraints
        
        // "q" must be part of "qu" and followed by another vowel
        if lowerInitial == "q" {
            if !vowelRunBase.hasPrefix("u") {
                return false
            }
        }
        
        // "io" is only valid if the initial is "g" (e.g. "gió", "giông")
        if vowelRunBase == "io" && lowerInitial != "g" {
            return false
        }
        
        // "gh" and "ngh" can only precede "e", "ê", "i", "y" -> bases "e", "i", "y"
        if lowerInitial == "gh" || lowerInitial == "ngh" {
            guard let firstBaseVowel = vowelRunBase.first,
                  firstBaseVowel == "e" || firstBaseVowel == "i" || firstBaseVowel == "y" else {
                return false
            }
        }
        
        // "k" can only precede "e", "ê", "i", "y" -> bases "e", "i", "y"
        if lowerInitial == "k" {
            guard let firstBaseVowel = vowelRunBase.first,
                  firstBaseVowel == "e" || firstBaseVowel == "i" || firstBaseVowel == "y" else {
                return false
            }
        }
        
        // "c" cannot precede "e", "ê", "i", "y" -> bases "e", "i", "y"
        if lowerInitial == "c" {
            if let firstBaseVowel = vowelRunBase.first {
                if firstBaseVowel == "e" || firstBaseVowel == "i" || firstBaseVowel == "y" {
                    return false
                }
            }
        }
        
        // "ch" and "nh" as finals can only follow "a", "e", "i"
        if lowerFinal == "ch" || lowerFinal == "nh" {
            guard let lastBaseVowel = vowelRunBase.last,
                  lastBaseVowel == "a" || lastBaseVowel == "e" || lastBaseVowel == "i" || lastBaseVowel == "y" else {
                return false
            }
        }
        
        // "ie" and "ye" as vowel runs are only valid if followed by a final consonant
        if (vowelRunBase == "ie" || vowelRunBase == "ye") && lowerFinal.isEmpty {
            return false
        }
        
        return true
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
 
    private static let reverseTable: [Character: (base: Character, tone: PHTVTone)] = {
        var rev: [Character: (Character, PHTVTone)] = [:]
        for (base, tones) in table {
            for (tone, char) in tones {
                rev[char] = (base, tone)
            }
        }
        return rev
    }()

    static func decompose(_ character: Character) -> (base: Character, tone: PHTVTone?) {
        if let match = reverseTable[character] {
            return (match.base, match.tone)
        }
        return (character, nil)
    }

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
