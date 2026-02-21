//
//  EngineMacroSnippetRuntime.swift
//  PHTV
//

import Foundation

private let engineSnippetTokenCharacters: Set<Character> = ["d", "M", "y", "H", "m", "s"]
private let engineSnippetCounterLock = NSLock()
nonisolated(unsafe) private var engineSnippetCounterValues: [String: Int] = [:]

enum EngineMacroSnippetType {
    static let staticContent: Int32 = 0
    static let date: Int32 = 1
    static let time: Int32 = 2
    static let dateTime: Int32 = 3
    static let clipboard: Int32 = 4
    static let random: Int32 = 5
    static let counter: Int32 = 6
}

enum EngineMacroSnippetRuntime {
    private static func twoDigitString(_ value: Int) -> String {
        String(format: "%02d", value)
    }

    private static func formatDateTime(_ format: String) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .month, .year, .hour, .minute, .second], from: now)
        let day = components.day ?? 0
        let month = components.month ?? 0
        let year = components.year ?? 0
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0

        var output = ""
        var lastCharacter: Character?
        var repeatCount = 0

        func flushRepeat() {
            guard let character = lastCharacter, repeatCount > 0 else {
                return
            }

            switch character {
            case "d":
                output.append(repeatCount >= 2 ? twoDigitString(day) : String(day))
            case "M":
                output.append(repeatCount >= 2 ? twoDigitString(month) : String(month))
            case "y":
                if repeatCount >= 4 {
                    output.append(String(year))
                } else {
                    output.append(twoDigitString(year % 100))
                }
            case "H":
                output.append(repeatCount >= 2 ? twoDigitString(hour) : String(hour))
            case "m":
                output.append(repeatCount >= 2 ? twoDigitString(minute) : String(minute))
            case "s":
                output.append(repeatCount >= 2 ? twoDigitString(second) : String(second))
            default:
                for _ in 0..<repeatCount {
                    output.append(character)
                }
            }

            repeatCount = 0
        }

        for character in format {
            if character == lastCharacter, engineSnippetTokenCharacters.contains(character) {
                repeatCount += 1
            } else {
                flushRepeat()
                lastCharacter = character
                repeatCount = 1
            }
        }
        flushRepeat()

        return output
    }

    private static func randomValue(from list: String) -> String {
        guard !list.isEmpty else {
            return ""
        }

        let items = list
            .split(separator: ",", omittingEmptySubsequences: false)
            .compactMap { part -> String? in
                let trimmed = String(part).trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
                return trimmed.isEmpty ? nil : trimmed
            }

        guard !items.isEmpty else {
            return list
        }
        return items[Int.random(in: 0..<items.count)]
    }

    private static func counterValue(prefix: String) -> String {
        engineSnippetCounterLock.lock()
        defer {
            engineSnippetCounterLock.unlock()
        }

        let nextValue = (engineSnippetCounterValues[prefix] ?? 0) + 1
        engineSnippetCounterValues[prefix] = nextValue
        return "\(prefix)\(nextValue)"
    }

    static func content(snippetType: Int32, format: String) -> String {
        switch snippetType {
        case EngineMacroSnippetType.date:
            return formatDateTime(format.isEmpty ? "dd/MM/yyyy" : format)
        case EngineMacroSnippetType.time:
            return formatDateTime(format.isEmpty ? "HH:mm:ss" : format)
        case EngineMacroSnippetType.dateTime:
            return formatDateTime(format.isEmpty ? "dd/MM/yyyy HH:mm" : format)
        case EngineMacroSnippetType.clipboard:
            // Clipboard snippets are handled in AppDelegate layer.
            return ""
        case EngineMacroSnippetType.random:
            return randomValue(from: format)
        case EngineMacroSnippetType.counter:
            return counterValue(prefix: format)
        case EngineMacroSnippetType.staticContent:
            return format
        default:
            return format
        }
    }
}
