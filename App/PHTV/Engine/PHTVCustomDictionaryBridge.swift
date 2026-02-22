//
//  PHTVCustomDictionaryBridge.swift
//  PHTV
//
//  Swift runtime storage for custom English/Vietnamese dictionary words.
//

import Foundation

private let customDictionaryLock = NSLock()

private final class CustomDictionaryStateBox: @unchecked Sendable {
    var customEnglishWordsSwift: Set<String> = []
    var customVietnameseWordsSwift: Set<String> = []
}

private let customDictionaryState = CustomDictionaryStateBox()

private func normalizedCustomDictionaryWord(_ word: String) -> String {
    let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return ""
    }
    return trimmed.lowercased()
}

private func setCustomDictionaryWords(
    english: Set<String>,
    vietnamese: Set<String>
) {
    customDictionaryLock.lock()
    customDictionaryState.customEnglishWordsSwift = english
    customDictionaryState.customVietnameseWordsSwift = vietnamese
    customDictionaryLock.unlock()
}

@_cdecl("phtvCustomDictionaryClear")
func phtvCustomDictionaryClear() {
    setCustomDictionaryWords(english: [], vietnamese: [])
}

@_cdecl("phtvCustomDictionaryLoadJSON")
func phtvCustomDictionaryLoadJSON(_ jsonData: UnsafePointer<CChar>?, _ length: Int32) {
    guard let jsonData, length > 0 else {
        phtvCustomDictionaryClear()
        return
    }

    let data = Data(bytes: jsonData, count: Int(length))
    guard let payload = try? JSONSerialization.jsonObject(with: data, options: []),
          let entries = payload as? [Any] else {
        phtvCustomDictionaryClear()
        return
    }

    var english: Set<String> = []
    var vietnamese: Set<String> = []

    for entry in entries {
        guard let dict = entry as? [String: Any],
              let rawWord = dict["word"] as? String,
              let rawType = dict["type"] as? String else {
            continue
        }

        let word = normalizedCustomDictionaryWord(rawWord)
        guard !word.isEmpty else {
            continue
        }

        switch rawType.lowercased() {
        case "en", "english":
            english.insert(word)
        case "vi", "vietnamese":
            vietnamese.insert(word)
        default:
            continue
        }
    }

    setCustomDictionaryWords(english: english, vietnamese: vietnamese)
}

@_cdecl("phtvCustomDictionaryEnglishCount")
func phtvCustomDictionaryEnglishCount() -> Int32 {
    customDictionaryLock.lock()
    let count = customDictionaryState.customEnglishWordsSwift.count
    customDictionaryLock.unlock()
    return Int32(clamping: count)
}

@_cdecl("phtvCustomDictionaryVietnameseCount")
func phtvCustomDictionaryVietnameseCount() -> Int32 {
    customDictionaryLock.lock()
    let count = customDictionaryState.customVietnameseWordsSwift.count
    customDictionaryLock.unlock()
    return Int32(clamping: count)
}

@_cdecl("phtvCustomDictionaryContainsEnglishWord")
func phtvCustomDictionaryContainsEnglishWord(_ wordCString: UnsafePointer<CChar>?) -> Int32 {
    guard let wordCString else {
        return 0
    }

    let word = normalizedCustomDictionaryWord(String(cString: wordCString))
    guard !word.isEmpty else {
        return 0
    }

    customDictionaryLock.lock()
    let contains = customDictionaryState.customEnglishWordsSwift.contains(word)
    customDictionaryLock.unlock()
    return contains ? 1 : 0
}

@_cdecl("phtvCustomDictionaryContainsVietnameseWord")
func phtvCustomDictionaryContainsVietnameseWord(_ wordCString: UnsafePointer<CChar>?) -> Int32 {
    guard let wordCString else {
        return 0
    }

    let word = normalizedCustomDictionaryWord(String(cString: wordCString))
    guard !word.isEmpty else {
        return 0
    }

    customDictionaryLock.lock()
    let contains = customDictionaryState.customVietnameseWordsSwift.contains(word)
    customDictionaryLock.unlock()
    return contains ? 1 : 0
}
