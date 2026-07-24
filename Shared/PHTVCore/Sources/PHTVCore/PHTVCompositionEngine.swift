struct PHTVCompositionEngine: Sendable {
    private static let maximumRawKeyCount = 64

    private var rawKeys: [Unicode.Scalar] = []
    private var renderedWord = ""
    private var activeMethod: PHTVInputMethod?

    mutating func reset() {
        rawKeys.removeAll(keepingCapacity: true)
        renderedWord.removeAll(keepingCapacity: true)
        activeMethod = nil
    }

    mutating func handle(
        scalar: Unicode.Scalar,
        method: PHTVInputMethod
    ) -> PHTVCompositionChange {
        if activeMethod != method {
            reset()
            activeMethod = method
        }

        guard Self.isASCIIWordKey(scalar, method: method) else {
            reset()
            return .passThrough
        }

        if rawKeys.count >= Self.maximumRawKeyCount {
            reset()
            activeMethod = method
        }

        let previous = renderedWord
        rawKeys.append(scalar)
        renderedWord = PHTVVietnameseRenderer.render(rawKeys, method: method)

        let literalAppend = previous + String(scalar)
        if renderedWord == literalAppend {
            return .passThrough
        }

        return .replace(
            previous: previous,
            replacement: renderedWord
        )
    }

    mutating func handleBackspace(method: PHTVInputMethod) -> PHTVCompositionChange {
        guard activeMethod == method, !rawKeys.isEmpty else {
            reset()
            return .passThrough
        }

        let previous = renderedWord
        rawKeys.removeLast()
        renderedWord = PHTVVietnameseRenderer.render(rawKeys, method: method)

        if rawKeys.isEmpty {
            activeMethod = nil
        }

        if String(previous.dropLast()) == renderedWord {
            return .passThrough
        }

        return .replace(
            previous: previous,
            replacement: renderedWord
        )
    }

    private static func isASCIIWordKey(
        _ scalar: Unicode.Scalar,
        method: PHTVInputMethod
    ) -> Bool {
        let value = scalar.value
        let isLetter =
            (Unicode.Scalar("a").value...Unicode.Scalar("z").value).contains(value)
            || (Unicode.Scalar("A").value...Unicode.Scalar("Z").value).contains(value)
        let isDigit =
            (Unicode.Scalar("0").value...Unicode.Scalar("9").value).contains(value)

        return isLetter || (method == .vni && isDigit)
    }
}

enum PHTVCompositionChange: Equatable, Sendable {
    case passThrough
    case replace(previous: String, replacement: String)
}

private enum PHTVTone: Int, Sendable {
    case none = 0
    case acute
    case grave
    case hook
    case tilde
    case dot
}

private enum PHTVDecoration: UInt8, Sendable {
    case none
    case breve
    case circumflex
    case horn
    case stroke
}

private struct PHTVGlyph: Sendable {
    var ascii: UInt8
    var uppercase: Bool
    var decoration: PHTVDecoration = .none
    var tone: PHTVTone = .none

    var isVowel: Bool {
        switch ascii {
        case CharacterASCII.a, CharacterASCII.e, CharacterASCII.i,
            CharacterASCII.o, CharacterASCII.u, CharacterASCII.y:
            true
        default:
            false
        }
    }
}

private enum CharacterASCII {
    static let zero = UInt8(ascii: "0")
    static let nine = UInt8(ascii: "9")
    static let a = UInt8(ascii: "a")
    static let d = UInt8(ascii: "d")
    static let e = UInt8(ascii: "e")
    static let g = UInt8(ascii: "g")
    static let i = UInt8(ascii: "i")
    static let j = UInt8(ascii: "j")
    static let o = UInt8(ascii: "o")
    static let q = UInt8(ascii: "q")
    static let u = UInt8(ascii: "u")
    static let w = UInt8(ascii: "w")
    static let y = UInt8(ascii: "y")
    static let z = UInt8(ascii: "z")
}

private enum PHTVVietnameseRenderer {
    static func render(
        _ rawKeys: [Unicode.Scalar],
        method: PHTVInputMethod
    ) -> String {
        var glyphs: [PHTVGlyph] = []
        glyphs.reserveCapacity(rawKeys.count)

        for scalar in rawKeys {
            switch method {
            case .telex:
                applyTelex(scalar, to: &glyphs)
            case .vni:
                applyVNI(scalar, to: &glyphs)
            }
            normalizeTonePlacement(in: &glyphs)
        }

        return String(glyphs.map(renderGlyph))
    }

    private static func applyTelex(
        _ scalar: Unicode.Scalar,
        to glyphs: inout [PHTVGlyph]
    ) {
        guard let key = asciiKey(scalar) else {
            return
        }

        switch key.ascii {
        case CharacterASCII.a, CharacterASCII.e, CharacterASCII.o:
            if applyCircumflex(key, to: &glyphs) {
                return
            }
        case CharacterASCII.d:
            if applyStroke(key, to: &glyphs) {
                return
            }
        case CharacterASCII.w:
            if applyTelexW(key, to: &glyphs) {
                return
            }
        case UInt8(ascii: "s"):
            if applyTone(.acute, command: key, to: &glyphs) {
                return
            }
        case UInt8(ascii: "f"):
            if applyTone(.grave, command: key, to: &glyphs) {
                return
            }
        case UInt8(ascii: "r"):
            if applyTone(.hook, command: key, to: &glyphs) {
                return
            }
        case UInt8(ascii: "x"):
            if applyTone(.tilde, command: key, to: &glyphs) {
                return
            }
        case CharacterASCII.j:
            if applyTone(.dot, command: key, to: &glyphs) {
                return
            }
        case CharacterASCII.z:
            if clearDiacritics(in: &glyphs) {
                return
            }
        default:
            break
        }

        glyphs.append(key)
    }

    private static func applyVNI(
        _ scalar: Unicode.Scalar,
        to glyphs: inout [PHTVGlyph]
    ) {
        guard let key = asciiKey(scalar) else {
            return
        }

        switch key.ascii {
        case UInt8(ascii: "1"):
            if applyTone(.acute, command: key, to: &glyphs) {
                return
            }
        case UInt8(ascii: "2"):
            if applyTone(.grave, command: key, to: &glyphs) {
                return
            }
        case UInt8(ascii: "3"):
            if applyTone(.hook, command: key, to: &glyphs) {
                return
            }
        case UInt8(ascii: "4"):
            if applyTone(.tilde, command: key, to: &glyphs) {
                return
            }
        case UInt8(ascii: "5"):
            if applyTone(.dot, command: key, to: &glyphs) {
                return
            }
        case UInt8(ascii: "6"):
            if applyVNICircumflex(command: key, to: &glyphs) {
                return
            }
        case UInt8(ascii: "7"):
            if applyVNIHorn(command: key, to: &glyphs) {
                return
            }
        case UInt8(ascii: "8"):
            if applyVNIBreve(command: key, to: &glyphs) {
                return
            }
        case UInt8(ascii: "9"):
            if applyVNIStroke(command: key, to: &glyphs) {
                return
            }
        case CharacterASCII.zero:
            if clearDiacritics(in: &glyphs) {
                return
            }
        default:
            break
        }

        glyphs.append(key)
    }

    private static func asciiKey(_ scalar: Unicode.Scalar) -> PHTVGlyph? {
        let value = scalar.value
        let uppercaseRange = Unicode.Scalar("A").value...Unicode.Scalar("Z").value
        let lowercaseRange = Unicode.Scalar("a").value...Unicode.Scalar("z").value
        let digitRange = Unicode.Scalar("0").value...Unicode.Scalar("9").value

        if uppercaseRange.contains(value) {
            return PHTVGlyph(
                ascii: UInt8(value + 32),
                uppercase: true
            )
        }
        if lowercaseRange.contains(value) || digitRange.contains(value) {
            return PHTVGlyph(
                ascii: UInt8(value),
                uppercase: false
            )
        }
        return nil
    }

    private static func applyCircumflex(
        _ command: PHTVGlyph,
        to glyphs: inout [PHTVGlyph]
    ) -> Bool {
        guard let index = glyphs.indices.last, glyphs[index].ascii == command.ascii else {
            return false
        }

        switch glyphs[index].decoration {
        case .none:
            glyphs[index].decoration = .circumflex
        case .circumflex:
            glyphs[index].decoration = .none
            glyphs.append(command)
        default:
            return false
        }
        return true
    }

    private static func applyStroke(
        _ command: PHTVGlyph,
        to glyphs: inout [PHTVGlyph]
    ) -> Bool {
        guard let index = glyphs.indices.last, glyphs[index].ascii == CharacterASCII.d else {
            return false
        }

        switch glyphs[index].decoration {
        case .none:
            glyphs[index].decoration = .stroke
        case .stroke:
            glyphs[index].decoration = .none
            glyphs.append(command)
        default:
            return false
        }
        return true
    }

    private static func applyTelexW(
        _ command: PHTVGlyph,
        to glyphs: inout [PHTVGlyph]
    ) -> Bool {
        if glyphs.count >= 2 {
            let uIndex = glyphs.index(glyphs.endIndex, offsetBy: -2)
            let oIndex = glyphs.index(before: glyphs.endIndex)
            if glyphs[uIndex].ascii == CharacterASCII.u,
                glyphs[oIndex].ascii == CharacterASCII.o,
                glyphs[uIndex].decoration == .none,
                glyphs[oIndex].decoration == .none
            {
                glyphs[uIndex].decoration = .horn
                glyphs[oIndex].decoration = .horn
                return true
            }
        }

        guard
            let index = glyphs.lastIndex(where: {
                $0.ascii == CharacterASCII.a
                    || $0.ascii == CharacterASCII.o
                    || $0.ascii == CharacterASCII.u
            })
        else {
            glyphs.append(
                PHTVGlyph(
                    ascii: CharacterASCII.u,
                    uppercase: command.uppercase,
                    decoration: .horn
                )
            )
            return true
        }

        let targetDecoration: PHTVDecoration =
            glyphs[index].ascii == CharacterASCII.a ? .breve : .horn
        switch glyphs[index].decoration {
        case .none:
            glyphs[index].decoration = targetDecoration
        case targetDecoration:
            glyphs[index].decoration = .none
            glyphs.append(command)
        default:
            return false
        }
        return true
    }

    private static func applyVNICircumflex(
        command: PHTVGlyph,
        to glyphs: inout [PHTVGlyph]
    ) -> Bool {
        guard
            let index = glyphs.lastIndex(where: {
                ($0.ascii == CharacterASCII.a
                    || $0.ascii == CharacterASCII.e
                    || $0.ascii == CharacterASCII.o)
                    && ($0.decoration == .none || $0.decoration == .circumflex)
            })
        else {
            return false
        }

        if glyphs[index].decoration == .circumflex {
            glyphs[index].decoration = .none
            glyphs.append(command)
        } else {
            glyphs[index].decoration = .circumflex
        }
        return true
    }

    private static func applyVNIHorn(
        command: PHTVGlyph,
        to glyphs: inout [PHTVGlyph]
    ) -> Bool {
        if glyphs.count >= 2 {
            let uIndex = glyphs.index(glyphs.endIndex, offsetBy: -2)
            let oIndex = glyphs.index(before: glyphs.endIndex)
            if glyphs[uIndex].ascii == CharacterASCII.u,
                glyphs[oIndex].ascii == CharacterASCII.o,
                glyphs[uIndex].decoration == .none,
                glyphs[oIndex].decoration == .none
            {
                glyphs[uIndex].decoration = .horn
                glyphs[oIndex].decoration = .horn
                return true
            }
        }

        guard
            let index = glyphs.lastIndex(where: {
                ($0.ascii == CharacterASCII.o || $0.ascii == CharacterASCII.u)
                    && ($0.decoration == .none || $0.decoration == .horn)
            })
        else {
            return false
        }

        if glyphs[index].decoration == .horn {
            glyphs[index].decoration = .none
            glyphs.append(command)
        } else {
            glyphs[index].decoration = .horn
        }
        return true
    }

    private static func applyVNIBreve(
        command: PHTVGlyph,
        to glyphs: inout [PHTVGlyph]
    ) -> Bool {
        guard
            let index = glyphs.lastIndex(where: {
                $0.ascii == CharacterASCII.a
                    && ($0.decoration == .none || $0.decoration == .breve)
            })
        else {
            return false
        }

        if glyphs[index].decoration == .breve {
            glyphs[index].decoration = .none
            glyphs.append(command)
        } else {
            glyphs[index].decoration = .breve
        }
        return true
    }

    private static func applyVNIStroke(
        command: PHTVGlyph,
        to glyphs: inout [PHTVGlyph]
    ) -> Bool {
        guard
            let index = glyphs.lastIndex(where: {
                $0.ascii == CharacterASCII.d
                    && ($0.decoration == .none || $0.decoration == .stroke)
            })
        else {
            return false
        }

        if glyphs[index].decoration == .stroke {
            glyphs[index].decoration = .none
            glyphs.append(command)
        } else {
            glyphs[index].decoration = .stroke
        }
        return true
    }

    private static func applyTone(
        _ tone: PHTVTone,
        command: PHTVGlyph,
        to glyphs: inout [PHTVGlyph]
    ) -> Bool {
        guard let target = toneTarget(in: glyphs) else {
            return false
        }

        let currentTone = glyphs.first(where: { $0.tone != .none })?.tone ?? .none
        for index in glyphs.indices {
            glyphs[index].tone = .none
        }

        if currentTone == tone {
            glyphs.append(command)
        } else {
            glyphs[target].tone = tone
        }
        return true
    }

    private static func clearDiacritics(in glyphs: inout [PHTVGlyph]) -> Bool {
        let hasDiacritics = glyphs.contains {
            $0.tone != .none || $0.decoration != .none
        }
        guard hasDiacritics else {
            return false
        }

        for index in glyphs.indices {
            glyphs[index].tone = .none
            glyphs[index].decoration = .none
        }
        return true
    }

    private static func normalizeTonePlacement(in glyphs: inout [PHTVGlyph]) {
        guard let tone = glyphs.first(where: { $0.tone != .none })?.tone,
            let target = toneTarget(in: glyphs)
        else {
            return
        }

        for index in glyphs.indices {
            glyphs[index].tone = .none
        }
        glyphs[target].tone = tone
    }

    private static func toneTarget(in glyphs: [PHTVGlyph]) -> Int? {
        var vowels = glyphs.indices.filter { glyphs[$0].isVowel }
        guard !vowels.isEmpty else {
            return nil
        }

        if vowels.count > 1,
            let first = vowels.first,
            first > glyphs.startIndex
        {
            let prior = glyphs[glyphs.index(before: first)].ascii
            if (prior == CharacterASCII.q && glyphs[first].ascii == CharacterASCII.u)
                || (prior == CharacterASCII.g && glyphs[first].ascii == CharacterASCII.i)
            {
                vowels.removeFirst()
            }
        }

        guard !vowels.isEmpty else {
            return nil
        }

        let decorated = vowels.filter { glyphs[$0].decoration != .none }
        if let preferred = decorated.last {
            return preferred
        }
        if vowels.count == 1 {
            return vowels[0]
        }
        if vowels.count >= 3 {
            return vowels[vowels.count - 2]
        }

        guard let lastVowel = vowels.last else {
            return nil
        }
        let hasTrailingConsonant = glyphs.index(after: lastVowel) < glyphs.endIndex
        return hasTrailingConsonant ? lastVowel : vowels[0]
    }

    private static func renderGlyph(_ glyph: PHTVGlyph) -> Character {
        if glyph.decoration == .stroke {
            return glyph.uppercase ? "Đ" : "đ"
        }

        let key =
            String(Unicode.Scalar(glyph.ascii))
            + "."
            + String(glyph.decoration.rawValue)
        guard let variants = toneVariants[key] else {
            let scalar =
                glyph.uppercase && glyph.ascii >= CharacterASCII.a
                ? Unicode.Scalar(glyph.ascii - 32)
                : Unicode.Scalar(glyph.ascii)
            return Character(String(scalar))
        }
        return glyph.uppercase
            ? variants.upper[glyph.tone.rawValue]
            : variants.lower[glyph.tone.rawValue]
    }

    private static let toneVariants: [String: (lower: [Character], upper: [Character])] = [
        "a.0": (Array("aáàảãạ"), Array("AÁÀẢÃẠ")),
        "a.1": (Array("ăắằẳẵặ"), Array("ĂẮẰẲẴẶ")),
        "a.2": (Array("âấầẩẫậ"), Array("ÂẤẦẨẪẬ")),
        "e.0": (Array("eéèẻẽẹ"), Array("EÉÈẺẼẸ")),
        "e.2": (Array("êếềểễệ"), Array("ÊẾỀỂỄỆ")),
        "i.0": (Array("iíìỉĩị"), Array("IÍÌỈĨỊ")),
        "o.0": (Array("oóòỏõọ"), Array("OÓÒỎÕỌ")),
        "o.2": (Array("ôốồổỗộ"), Array("ÔỐỒỔỖỘ")),
        "o.3": (Array("ơớờởỡợ"), Array("ƠỚỜỞỠỢ")),
        "u.0": (Array("uúùủũụ"), Array("UÚÙỦŨỤ")),
        "u.3": (Array("ưứừửữự"), Array("ƯỨỪỬỮỰ")),
        "y.0": (Array("yýỳỷỹỵ"), Array("YÝỲỶỸỴ")),
    ]
}
