#!/usr/bin/swift

import Foundation
import Darwin

private let trieMagic = "PHT4"
private let maxEnglishWords = Int.max
private let maxEnglishLength = 45
private let maxTelexLength = 30
private let sparkleLine = String(repeating: "=", count: 60)

private extension Data {
    mutating func appendLEUInt32(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { buffer in
            append(contentsOf: buffer)
        }
    }

    mutating func appendLEUInt24(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
    }
}

private extension Character {
    var isASCIIAlphabetic: Bool {
        guard unicodeScalars.count == 1, let scalar = unicodeScalars.first else {
            return false
        }

        switch scalar.value {
        case 65...90, 97...122:
            return true
        default:
            return false
        }
    }

    var lowercasedASCIIString: String {
        String(self).lowercased()
    }
}

private func isASCIIAlphabetic(_ text: String) -> Bool {
    !text.isEmpty && text.allSatisfy { $0.isASCIIAlphabetic }
}

private func isAlphabeticUnicodeWord(_ text: String) -> Bool {
    !text.isEmpty && text.unicodeScalars.allSatisfy(CharacterSet.letters.contains)
}

private func printSection(_ title: String) {
    print("\n\(sparkleLine)")
    print(title)
    print(sparkleLine)
}

private struct TrieNode {
    var children: [Int?] = Array(repeating: nil, count: 26)
    var isEnd: Bool = false
}

private final class Trie {
    private(set) var nodes: [TrieNode] = [TrieNode()]
    private(set) var wordCount = 0

    @discardableResult
    func insert(_ word: String) -> Bool {
        var currentIndex = 0

        for scalar in word.unicodeScalars {
            guard (97...122).contains(scalar.value) else {
                return false
            }

            let childIndex = Int(scalar.value - 97)
            if let next = nodes[currentIndex].children[childIndex] {
                currentIndex = next
            } else {
                let newNodeIndex = nodes.count
                nodes.append(TrieNode())
                nodes[currentIndex].children[childIndex] = newNodeIndex
                currentIndex = newNodeIndex
            }
        }

        if !nodes[currentIndex].isEnd {
            nodes[currentIndex].isEnd = true
            wordCount += 1
            return true
        }

        return false
    }

    func serialize() -> Data {
        var data = Data()
        data.reserveCapacity(nodes.count * 79) // 26×3 + 1

        for node in nodes {
            for child in node.children {
                let childValue = child.map { UInt32($0) } ?? 0xFFFFFF
                data.appendLEUInt24(childValue)
            }
            data.append(node.isEnd ? 1 : 0)
        }

        return data
    }
}

private let vietnameseToTelexMap: [Character: String] = [
    "a": "a", "à": "af", "á": "as", "ả": "ar", "ã": "ax", "ạ": "aj",
    "ă": "aw", "ằ": "awf", "ắ": "aws", "ẳ": "awr", "ẵ": "awx", "ặ": "awj",
    "â": "aa", "ầ": "aaf", "ấ": "aas", "ẩ": "aar", "ẫ": "aax", "ậ": "aaj",
    "e": "e", "è": "ef", "é": "es", "ẻ": "er", "ẽ": "ex", "ẹ": "ej",
    "ê": "ee", "ề": "eef", "ế": "ees", "ể": "eer", "ễ": "eex", "ệ": "eej",
    "i": "i", "ì": "if", "í": "is", "ỉ": "ir", "ĩ": "ix", "ị": "ij",
    "o": "o", "ò": "of", "ó": "os", "ỏ": "or", "õ": "ox", "ọ": "oj",
    "ô": "oo", "ồ": "oof", "ố": "oos", "ổ": "oor", "ỗ": "oox", "ộ": "ooj",
    "ơ": "ow", "ờ": "owf", "ớ": "ows", "ở": "owr", "ỡ": "owx", "ợ": "owj",
    "u": "u", "ù": "uf", "ú": "us", "ủ": "ur", "ũ": "ux", "ụ": "uj",
    "ư": "uw", "ừ": "uwf", "ứ": "uws", "ử": "uwr", "ữ": "uwx", "ự": "uwj",
    "y": "y", "ỳ": "yf", "ý": "ys", "ỷ": "yr", "ỹ": "yx", "ỵ": "yj",
    "đ": "dd"
]

private let toneMarks: Set<Character> = ["f", "s", "r", "x", "j"]
private let toneBeforeShapeDigraphs: Set<String> = ["aa", "aw", "ee", "oo", "ow", "uw"]

private struct VietnameseTelexConversion {
    let baseWord: String
    let variants: [String]
    let hasModifier: Bool
    let hasToneMark: Bool
}

private func toneBeforeShapeVariants(baseWord: String, tone: String) -> [String] {
    let characters = Array(baseWord)
    guard characters.count >= 2 else { return [] }

    var variants = Set<String>()

    for index in 0..<(characters.count - 1) {
        let digraph = String(characters[index]) + String(characters[index + 1])
        guard toneBeforeShapeDigraphs.contains(digraph) else {
            continue
        }

        var variant = ""
        variant.reserveCapacity(baseWord.count + tone.count)

        for (characterIndex, character) in characters.enumerated() {
            if characterIndex == index + 1 {
                variant.append(contentsOf: tone)
            }
            variant.append(character)
        }

        variants.insert(variant)
    }

    return Array(variants)
}

private func vietnameseToTelexConversion(_ word: String) -> VietnameseTelexConversion? {
    var baseParts: [String] = []
    var tones: [String] = []
    var hasModifier = false
    var hasToneMark = false

    for character in word {
        if let telex = vietnameseToTelexMap[character] {
            let lowercaseCharacter = character.lowercasedASCIIString
            if telex != lowercaseCharacter {
                hasModifier = true
            }
            if let last = telex.last, toneMarks.contains(last), telex.count >= 2 {
                baseParts.append(String(telex.dropLast()))
                tones.append(String(last))
                hasToneMark = true
            } else {
                baseParts.append(telex)
            }
        } else if character.isASCIIAlphabetic {
            baseParts.append(character.lowercasedASCIIString)
        } else {
            return nil
        }
    }

    guard !baseParts.isEmpty else {
        return nil
    }

    let baseWord = baseParts.joined()
    var variants: Set<String> = [baseWord]

    if !tones.isEmpty {
        var inlineParts: [String] = []
        inlineParts.reserveCapacity(word.count)

        for character in word {
            if let telex = vietnameseToTelexMap[character] {
                inlineParts.append(telex)
            } else if character.isASCIIAlphabetic {
                inlineParts.append(character.lowercasedASCIIString)
            }
        }

        variants.insert(inlineParts.joined())
        variants.insert(baseWord + tones.joined())

        if tones.count == 1, let tone = tones.first {
            variants.insert(baseWord + tone)
            variants.formUnion(toneBeforeShapeVariants(baseWord: baseWord, tone: String(tone)))
        }
    }

    return VietnameseTelexConversion(
        baseWord: baseWord,
        variants: Array(variants),
        hasModifier: hasModifier || !tones.isEmpty,
        hasToneMark: hasToneMark
    )
}

private func vietnameseToTelexVariants(_ word: String) -> [String] {
    vietnameseToTelexConversion(word)?.variants ?? []
}

@discardableResult
private func writeBinaryTrie(_ trie: Trie, outputURL: URL) throws -> Int {
    let fileManager = FileManager.default
    let directory = outputURL.deletingLastPathComponent()
    if !fileManager.fileExists(atPath: directory.path) {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    var data = Data()
    data.append(trieMagic.data(using: .utf8)!)
    data.appendLEUInt32(UInt32(trie.nodes.count))
    data.appendLEUInt32(UInt32(trie.wordCount))
    data.append(trie.serialize())

    try data.write(to: outputURL, options: .atomic)

    print("  ✓ Nodes: \(trie.nodes.count.formatted()), Words: \(trie.wordCount.formatted()), Size: \(data.count.formatted()) bytes")
    return data.count
}

private struct LocalSourceDiagnostics {
    let totalEntries: Int
    let uniqueEntries: Int
    let duplicateEntries: Int
    let invalidEntries: Int

    var hasEntries: Bool {
        uniqueEntries > 0
    }

    var hasQualityIssues: Bool {
        duplicateEntries > 0 || invalidEntries > 0
    }
}

private func parseLocalEnglishWordFile(_ fileURL: URL) -> (Set<String>, LocalSourceDiagnostics) {
    guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
        return ([], LocalSourceDiagnostics(totalEntries: 0, uniqueEntries: 0, duplicateEntries: 0, invalidEntries: 0))
    }

    var words = Set<String>()
    var totalEntries = 0
    var invalidEntries = 0

    for line in text.split(whereSeparator: \.isNewline) {
        let normalizedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLine.isEmpty, !normalizedLine.hasPrefix("#") else {
            continue
        }

        totalEntries += 1
        let word = normalizedLine.lowercased()
        guard !word.isEmpty,
              word.count >= 2,
              word.count <= maxEnglishLength,
              isASCIIAlphabetic(word) else {
            invalidEntries += 1
            continue
        }
        words.insert(word)
    }

    return (
        words,
        LocalSourceDiagnostics(
            totalEntries: totalEntries,
            uniqueEntries: words.count,
            duplicateEntries: max(0, totalEntries - invalidEntries - words.count),
            invalidEntries: invalidEntries
        )
    )
}

private func parseLocalVietnameseWordFile(_ fileURL: URL) -> (Set<String>, LocalSourceDiagnostics) {
    guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
        return ([], LocalSourceDiagnostics(totalEntries: 0, uniqueEntries: 0, duplicateEntries: 0, invalidEntries: 0))
    }

    var words = Set<String>()
    var totalEntries = 0
    var invalidEntries = 0

    for line in text.split(whereSeparator: \.isNewline) {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !normalized.hasPrefix("#") else {
            continue
        }

        for part in normalized.replacingOccurrences(of: "-", with: " ").split(whereSeparator: \.isWhitespace) {
            totalEntries += 1
            let word = (String(part) as NSString).precomposedStringWithCanonicalMapping.lowercased()
            guard !word.isEmpty, isAlphabeticUnicodeWord(word) else {
                invalidEntries += 1
                continue
            }
            words.insert(word)
        }
    }

    return (
        words,
        LocalSourceDiagnostics(
            totalEntries: totalEntries,
            uniqueEntries: words.count,
            duplicateEntries: max(0, totalEntries - invalidEntries - words.count),
            invalidEntries: invalidEntries
        )
    )
}

private func printLocalSourceDiagnostics(name: String, diagnostics: LocalSourceDiagnostics) {
    print(
        "  \(name): \(diagnostics.uniqueEntries.formatted()) unique, " +
        "\(diagnostics.duplicateEntries.formatted()) duplicates, " +
        "\(diagnostics.invalidEntries.formatted()) invalid"
    )
}

private func preferredLineEnding(for fileURL: URL) -> String {
    guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
        return "\n"
    }

    return data.contains(Data([0x0D, 0x0A])) ? "\r\n" : "\n"
}

private func normalizedEnglishWordsPreservingOrder(from fileURL: URL) -> [String] {
    guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
        return []
    }

    var words: [String] = []
    var seen = Set<String>()

    for line in text.split(whereSeparator: \.isNewline) {
        let normalizedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLine.isEmpty, !normalizedLine.hasPrefix("#") else {
            continue
        }

        let word = normalizedLine.lowercased()
        guard word.count >= 2,
              word.count <= maxEnglishLength,
              isASCIIAlphabetic(word),
              seen.insert(word).inserted else {
            continue
        }

        words.append(word)
    }

    return words
}

private func normalizedVietnameseWordsPreservingOrder(from fileURL: URL) -> [String] {
    guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
        return []
    }

    var words: [String] = []
    var seen = Set<String>()

    for line in text.split(whereSeparator: \.isNewline) {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !normalized.hasPrefix("#") else {
            continue
        }

        for part in normalized.replacingOccurrences(of: "-", with: " ").split(whereSeparator: \.isWhitespace) {
            let word = (String(part) as NSString).precomposedStringWithCanonicalMapping.lowercased()
            guard !word.isEmpty,
                  isAlphabeticUnicodeWord(word),
                  seen.insert(word).inserted else {
                continue
            }
            words.append(word)
        }
    }

    return words
}

private func checkLocalDictionarySources(dictionarySourceDir: URL, strict: Bool) -> Bool {
    printSection("CHECKING LOCAL DICTIONARY SOURCES")

    let englishURL = dictionarySourceDir.appendingPathComponent("en_words.txt")
    let vietnameseURL = dictionarySourceDir.appendingPathComponent("vi_words.txt")

    let (englishWords, englishDiagnostics) = parseLocalEnglishWordFile(englishURL)
    let (vietnameseWords, vietnameseDiagnostics) = parseLocalVietnameseWordFile(vietnameseURL)

    printLocalSourceDiagnostics(name: "en_words.txt", diagnostics: englishDiagnostics)
    printLocalSourceDiagnostics(name: "vi_words.txt", diagnostics: vietnameseDiagnostics)

    let hasWords = !englishWords.isEmpty && !vietnameseWords.isEmpty
    if !hasWords {
        print("  ✗ Dictionary source files must contain at least one valid word each")
    }

    if strict {
        var hasStrictFailure = false

        if englishDiagnostics.hasQualityIssues {
            print("  ✗ en_words.txt still contains duplicates or invalid entries")
            hasStrictFailure = true
        }

        if vietnameseDiagnostics.hasQualityIssues {
            print("  ✗ vi_words.txt still contains duplicates or invalid entries")
            hasStrictFailure = true
        }

        if hasWords && !hasStrictFailure {
            print("  ✓ Local dictionary sources are normalized and strict-check clean")
        }

        return hasWords && !hasStrictFailure
    }

    return hasWords
}

private func normalizeLocalDictionarySources(dictionarySourceDir: URL) -> Bool {
    printSection("NORMALIZING LOCAL DICTIONARY SOURCES")

    let englishURL = dictionarySourceDir.appendingPathComponent("en_words.txt")
    let vietnameseURL = dictionarySourceDir.appendingPathComponent("vi_words.txt")

    let englishWords = normalizedEnglishWordsPreservingOrder(from: englishURL)
    let vietnameseWords = normalizedVietnameseWordsPreservingOrder(from: vietnameseURL)
    let (_, englishDiagnostics) = parseLocalEnglishWordFile(englishURL)
    let (_, vietnameseDiagnostics) = parseLocalVietnameseWordFile(vietnameseURL)
    let englishLineEnding = preferredLineEnding(for: englishURL)
    let vietnameseLineEnding = preferredLineEnding(for: vietnameseURL)

    guard !englishWords.isEmpty, !vietnameseWords.isEmpty else {
        print("  ✗ Cannot normalize empty dictionary source files")
        return false
    }

    do {
        try englishWords.joined(separator: englishLineEnding).appending(englishLineEnding).write(to: englishURL, atomically: true, encoding: .utf8)
        try vietnameseWords.joined(separator: vietnameseLineEnding).appending(vietnameseLineEnding).write(to: vietnameseURL, atomically: true, encoding: .utf8)
    } catch {
        print("  ✗ Failed to rewrite normalized sources: \(error.localizedDescription)")
        return false
    }

    printLocalSourceDiagnostics(name: "en_words.txt", diagnostics: englishDiagnostics)
    printLocalSourceDiagnostics(name: "vi_words.txt", diagnostics: vietnameseDiagnostics)
    print("  ✓ Rewrote local dictionary sources as unique valid word lists (preserving first-seen order)")
    return true
}

private func buildEnglishDictionary(resourcesDir: URL, dictionarySourceDir: URL) -> (Bool, Set<String>) {
    printSection("BUILDING ENGLISH DICTIONARY")

    let outputURL = resourcesDir.appendingPathComponent("en_dict.bin")

    // Canonical English source lives in docs/dictionary/en_words.txt.
    let canonicalEnglishFile = dictionarySourceDir.appendingPathComponent("en_words.txt")
    guard FileManager.default.fileExists(atPath: canonicalEnglishFile.path) else {
        print("  ✗ Missing canonical English source: \(canonicalEnglishFile.path)")
        return (false, [])
    }

    let (words, diagnostics) = parseLocalEnglishWordFile(canonicalEnglishFile)
    print("  Using canonical source: \(canonicalEnglishFile.lastPathComponent)")
    printLocalSourceDiagnostics(name: canonicalEnglishFile.lastPathComponent, diagnostics: diagnostics)

    guard !words.isEmpty else {
        print("  ✗ No English words found")
        return (false, [])
    }

    let filteredWords = words
    print("  No trimming needed: \(filteredWords.count.formatted()) words")

    print("  Building trie with \(filteredWords.count.formatted()) unique words...")
    let trie = Trie()
    for word in filteredWords.sorted() {
        trie.insert(word)
    }

    do {
        _ = try writeBinaryTrie(trie, outputURL: outputURL)
    } catch {
        print("  ✗ Failed to write English dictionary: \(error.localizedDescription)")
        return (false, [])
    }

    return (true, filteredWords)
}

private func buildVietnameseDictionary(
    resourcesDir: URL,
    englishWords: Set<String>,
    dictionarySourceDir: URL
) -> Bool {
    printSection("BUILDING VIETNAMESE DICTIONARY")

    let outputURL = resourcesDir.appendingPathComponent("vi_dict.bin")
    var vietnameseWords = Set<String>()
    let blacklist: Set<String> = ["tẻm"]

    let canonicalVietnameseFile = dictionarySourceDir.appendingPathComponent("vi_words.txt")
    guard FileManager.default.fileExists(atPath: canonicalVietnameseFile.path) else {
        print("  ✗ Missing canonical Vietnamese source: \(canonicalVietnameseFile.path)")
        return false
    }

    let (rawVietnameseWords, diagnostics) = parseLocalVietnameseWordFile(canonicalVietnameseFile)
    print("  Using canonical source: \(canonicalVietnameseFile.lastPathComponent)")
    printLocalSourceDiagnostics(name: canonicalVietnameseFile.lastPathComponent, diagnostics: diagnostics)
    for word in rawVietnameseWords {
        guard !blacklist.contains(word) else {
            continue
        }
        if word.count > 3 && englishWords.contains(word) {
            continue
        }
        vietnameseWords.insert(word)
    }

    guard !vietnameseWords.isEmpty else {
        print("  ✗ No Vietnamese words found")
        return false
    }

    print("  Converting \(vietnameseWords.count.formatted()) words to Telex (all variants)...")
    var telexWords = Set<String>()

    for word in vietnameseWords {
        guard let conversion = vietnameseToTelexConversion(word) else {
            continue
        }
        for variant in conversion.variants {
            guard variant.count >= 2,
                  variant.count <= maxTelexLength,
                  isASCIIAlphabetic(variant) else {
                continue
            }

            // Keep canonical shape-only Telex forms like "treen" -> "trên".
            // Only drop the plain base when the Vietnamese source word already
            // contains a tone mark and would otherwise shadow a real English word.
            if conversion.hasToneMark &&
                variant == conversion.baseWord &&
                englishWords.contains(variant) {
                continue
            }

            telexWords.insert(variant)

            if variant.hasPrefix("uw") || variant.hasPrefix("ow") {
                let standalone = "w" + variant.dropFirst(2)
                if standalone.count >= 2, standalone.count <= maxTelexLength, isASCIIAlphabetic(String(standalone)) {
                    telexWords.insert(String(standalone))
                }
            }
        }
    }

    print("  Generated \(telexWords.count.formatted()) unique Telex patterns (with variants, incl. standalone W)")

    let trie = Trie()
    for word in telexWords.sorted() {
        trie.insert(word)
    }

    do {
        _ = try writeBinaryTrie(trie, outputURL: outputURL)
    } catch {
        print("  ✗ Failed to write Vietnamese dictionary: \(error.localizedDescription)")
        return false
    }

    print("\n  Sample conversions (all variants):")
    for sample in ["còn", "công", "được", "không", "đến"] {
        let variants = vietnameseToTelexVariants(sample).sorted()
        print("    \(sample) -> \(variants)")
    }

    return true
}

private func cleanupTextFiles(resourcesDir: URL) {
    printSection("CLEANUP")

    let fileManager = FileManager.default
    for fileName in ["en_words.txt", "vi_words.txt"] {
        let path = resourcesDir.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: path.path) {
            do {
                try fileManager.removeItem(at: path)
                print("  ✓ Removed temporary \(fileName) from \(resourcesDir.path)")
            } catch {
                print("  ✗ Failed to remove \(path.path): \(error.localizedDescription)")
            }
        } else {
            print("  - Temporary \(fileName) not found in resources")
        }
    }

    print("  docs/dictionary/en_words.txt and vi_words.txt are preserved")
}

private func resolveResourcesDirectory(scriptDir: URL) -> URL {
    let fileManager = FileManager.default

    let repoRoot = scriptDir
        .deletingLastPathComponent() // scripts
        .deletingLastPathComponent() // repo root

    let candidates = [
        repoRoot.appendingPathComponent("App/PHTV/Resources/Dictionaries"),
        repoRoot.appendingPathComponent("scripts/Resources/Dictionaries"),
        repoRoot.appendingPathComponent("App/PHTV/Resources")
    ]

    if let existing = candidates.first(where: { fileManager.fileExists(atPath: $0.path) }) {
        return existing
    }

    return candidates[0]
}

private func printUsage() {
    print("Usage: ./scripts/tools/generate_dict_binary.swift [--cleanup] [--check-sources] [--strict-check-sources] [--normalize-sources] [--help]")
    print("  --cleanup  Remove temporary txt copies from Resources after successful generation")
    print("  --check-sources  Validate local dictionary source files and print diagnostics")
    print("  --strict-check-sources  Fail if local dictionary sources contain duplicates or invalid entries")
    print("  --normalize-sources  Rewrite local dictionary sources as unique valid word lists (preserving order)")
    print("  --help     Show this help message")
}

private func main() {
    let arguments = Set(CommandLine.arguments.dropFirst())

    if arguments.contains("--help") {
        printUsage()
        return
    }

    let scriptPath = URL(fileURLWithPath: #filePath).standardizedFileURL
    let scriptDir = scriptPath.deletingLastPathComponent()
    let repoRoot = scriptDir
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let dictionarySourceDir = repoRoot.appendingPathComponent("docs/dictionary")
    let resourcesDir = resolveResourcesDirectory(scriptDir: scriptDir)

    print(sparkleLine)
    print("PHTV Dictionary Generator")
    print(sparkleLine)
    print("Resources directory: \(resourcesDir.path)")
    print("Dictionary source directory: \(dictionarySourceDir.path)")

    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: resourcesDir.path) {
        do {
            try fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
        } catch {
            print("\n✗ Failed to create resources directory: \(error.localizedDescription)")
            exit(1)
        }
    }

    if arguments.contains("--check-sources") {
        let ok = checkLocalDictionarySources(dictionarySourceDir: dictionarySourceDir, strict: false)
        exit(ok ? 0 : 1)
    }

    if arguments.contains("--strict-check-sources") {
        let ok = checkLocalDictionarySources(dictionarySourceDir: dictionarySourceDir, strict: true)
        exit(ok ? 0 : 1)
    }

    if arguments.contains("--normalize-sources") {
        let ok = normalizeLocalDictionarySources(dictionarySourceDir: dictionarySourceDir)
        exit(ok ? 0 : 1)
    }
    let (englishOK, englishWords) = buildEnglishDictionary(resourcesDir: resourcesDir, dictionarySourceDir: dictionarySourceDir)
    let vietnameseOK = buildVietnameseDictionary(
        resourcesDir: resourcesDir,
        englishWords: englishWords,
        dictionarySourceDir: dictionarySourceDir
    )

    if englishOK && vietnameseOK {
        if arguments.contains("--cleanup") {
            cleanupTextFiles(resourcesDir: resourcesDir)
        } else {
            print("\n  Run with --cleanup to remove txt files")
        }
    }

    print("\n\(sparkleLine)")
    print("DONE!")
    print(sparkleLine)

    for fileName in ["en_dict.bin", "vi_dict.bin"] {
        let path = resourcesDir.appendingPathComponent(fileName)
        guard let attributes = try? fileManager.attributesOfItem(atPath: path.path),
              let size = attributes[.size] as? NSNumber else {
            continue
        }

        let bytes = size.intValue
        let kilobytes = Double(bytes) / 1024.0
        print("  \(fileName): \(bytes.formatted()) bytes (\(String(format: "%.1f", kilobytes)) KB)")
    }
}

main()
