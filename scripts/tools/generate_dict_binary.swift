#!/usr/bin/swift

import Foundation
import Darwin

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

private func downloadText(from urlString: String) -> String? {
    guard let url = URL(string: urlString) else {
        print("  ✗ Invalid URL: \(urlString)")
        return nil
    }

    print("  Downloading from \(urlString)...")

    do {
        let downloadedData = try Data(contentsOf: url)
        guard let text = String(data: downloadedData, encoding: .utf8) else {
            print("  ✗ Download failed: invalid UTF-8 response")
            return nil
        }
        return text
    } catch {
        print("  ✗ Download failed: \(error.localizedDescription)")
        return nil
    }
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

private func readLocalWordFile(_ fileURL: URL) -> Set<String> {
    guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
        return []
    }

    var words = Set<String>()
    for line in text.split(whereSeparator: \.isNewline) {
        let normalizedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLine.isEmpty, !normalizedLine.hasPrefix("#") else {
            continue
        }
        let word = normalizedLine.lowercased()
        guard !word.isEmpty,
              word.count >= 2,
              word.count <= maxEnglishLength,
              isASCIIAlphabetic(word) else {
            continue
        }
        words.insert(word)
    }

    return words
}

private func buildEnglishDictionary(resourcesDir: URL, dictionarySourceDir: URL) -> (Bool, Set<String>) {
    printSection("BUILDING ENGLISH DICTIONARY")

    let outputURL = resourcesDir.appendingPathComponent("en_dict.bin")
    var words = Set<String>()

    let sourceURLs = [
        "https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt"
    ]

    for sourceURL in sourceURLs {
        guard let text = downloadText(from: sourceURL) else {
            continue
        }

        for line in text.split(whereSeparator: \.isNewline) {
            let word = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !word.isEmpty,
                  word.count >= 2,
                  word.count <= maxEnglishLength,
                  isASCIIAlphabetic(word) else {
                continue
            }
            words.insert(word)
        }

        print("  Loaded \(words.count.formatted()) words so far")
    }

    // Canonical English source lives in docs/dictionary/en_words.txt.
    var localWords = Set<String>()
    let canonicalEnglishFile = dictionarySourceDir.appendingPathComponent("en_words.txt")
    if FileManager.default.fileExists(atPath: canonicalEnglishFile.path) {
        let fileWords = readLocalWordFile(canonicalEnglishFile)
        localWords.formUnion(fileWords)
        words.formUnion(fileWords)
        print("  Added local words from \(canonicalEnglishFile.lastPathComponent) (\(canonicalEnglishFile.deletingLastPathComponent().lastPathComponent)/), total: \(words.count.formatted())")
    }

    guard !words.isEmpty else {
        print("  ✗ No English words found")
        return (false, [])
    }

    let priorityWords = localWords
    let filteredWords: Set<String>

    if words.count > maxEnglishWords {
        let remainingSlots = max(0, maxEnglishWords - priorityWords.count)
        let candidates = words.subtracting(priorityWords).sorted {
            if $0.count != $1.count {
                return $0.count < $1.count
            }
            return $0 < $1
        }

        filteredWords = priorityWords.union(candidates.prefix(remainingSlots))
        print("  Trimmed to \(filteredWords.count.formatted()) words (shortest-first) to stay under \(maxEnglishWords.formatted())")
    } else {
        filteredWords = words
        print("  No trimming needed: \(filteredWords.count.formatted()) words")
    }

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

private func buildVietnameseDictionary(resourcesDir: URL, englishWords: Set<String>, dictionarySourceDir: URL) -> Bool {
    printSection("BUILDING VIETNAMESE DICTIONARY")

    let outputURL = resourcesDir.appendingPathComponent("vi_dict.bin")
    var vietnameseWords = Set<String>()

    let blacklist: Set<String> = ["tẻm"]

    let vietnameseURLs = [
        "https://raw.githubusercontent.com/duyet/vietnamese-wordlist/master/Viet74K.txt"
    ]

    for sourceURL in vietnameseURLs {
        guard let text = downloadText(from: sourceURL) else {
            continue
        }

        for line in text.split(whereSeparator: \.isNewline) {
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                continue
            }

            let parts = normalized.replacingOccurrences(of: "-", with: " ").split(whereSeparator: \.isWhitespace)
            for part in parts {
                let word = part.lowercased()
                guard !word.isEmpty, !blacklist.contains(word) else {
                    continue
                }

                if word.count > 3 && englishWords.contains(word) {
                    continue
                }

                vietnameseWords.insert(word)
            }
        }

        print("  Loaded \(vietnameseWords.count.formatted()) Vietnamese words total")
        break
    }

    let canonicalVietnameseFile = dictionarySourceDir.appendingPathComponent("vi_words.txt")
    let localCandidates = [canonicalVietnameseFile]

    for localFile in localCandidates where FileManager.default.fileExists(atPath: localFile.path) {
        guard let text = try? String(contentsOf: localFile, encoding: .utf8) else { continue }
        for line in text.split(whereSeparator: \.isNewline) {
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !normalized.hasPrefix("#") else { continue }
            for part in normalized.replacingOccurrences(of: "-", with: " ").split(whereSeparator: \.isWhitespace) {
                let word = part.lowercased()
                if !word.isEmpty { vietnameseWords.insert(word) }
            }
        }
        print("  Added local words from \(localFile.lastPathComponent) (\(localFile.deletingLastPathComponent().lastPathComponent)/), total: \(vietnameseWords.count.formatted())")
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
    print("Usage: ./scripts/tools/generate_dict_binary.swift [--cleanup] [--help]")
    print("  --cleanup  Remove temporary txt copies from Resources after successful generation")
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

    let (englishOK, englishWords) = buildEnglishDictionary(resourcesDir: resourcesDir, dictionarySourceDir: dictionarySourceDir)
    let vietnameseOK = buildVietnameseDictionary(resourcesDir: resourcesDir, englishWords: englishWords, dictionarySourceDir: dictionarySourceDir)

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
