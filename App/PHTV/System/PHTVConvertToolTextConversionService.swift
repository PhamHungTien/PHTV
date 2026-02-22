//
//  PHTVConvertToolTextConversionService.swift
//  PHTV
//
//  Swift implementation of Convert Tool text conversion.
//

import Foundation

@objcMembers
final class PHTVConvertToolTextConversionService: NSObject {
    private struct Options {
        var toAllCaps: Bool
        var toAllNonCaps: Bool
        var toCapsFirstLetter: Bool
        var toCapsEachWord: Bool
        var removeMark: Bool
        var fromCode: Int32
        var toCode: Int32
    }

    private static let keyToAllCaps = "convertToolToAllCaps"
    private static let keyToAllNonCaps = "convertToolToAllNonCaps"
    private static let keyToCapsFirstLetter = "convertToolToCapsFirstLetter"
    private static let keyToCapsEachWord = "convertToolToCapsEachWord"
    private static let keyRemoveMark = "convertToolRemoveMark"
    private static let keyFromCode = "convertToolFromCode"
    private static let keyToCode = "convertToolToCode"

    private static let breakCodes: Set<UInt16> = [46, 63, 33] // . ? !
    private static let defaultCodeTable = Int32(CodeTable.unicode.toIndex())
    private static let minCodeTable = Int32(CodeTable.unicode.toIndex())
    private static let maxCodeTable = Int32(CodeTable.cp1258.toIndex())

    @objc(convertText:)
    class func convertText(_ text: String) -> String {
        convert(text)
    }

    class func convert(_ text: String, defaults: UserDefaults = .standard) -> String {
        guard !text.isEmpty else {
            return text
        }

        let options = snapshotOptions(defaults: defaults)
        let source = Array(text.utf16)
        var converted: [UInt16] = []
        converted.reserveCapacity(source.count + 4)

        var hasBreak = false
        var shouldUpperCase = options.toCapsFirstLetter || options.toCapsEachWord
        var index = 0

        while index < source.count {
            if index + 1 < source.count {
                var compoundCharacter = source[index]
                var consumedExtra = 0
                var hasCompoundCandidate = false

                switch options.fromCode {
                case Int32(CodeTable.vniWindows.toIndex()),
                     Int32(CodeTable.cp1258.toIndex()):
                    compoundCharacter = source[index] | (source[index + 1] << 8)
                    consumedExtra = 1
                    hasCompoundCandidate = true

                case Int32(CodeTable.unicodeComposite.toIndex()):
                    let mark = unicodeCompoundMarkIndex(for: source[index + 1])
                    if mark > 0 {
                        compoundCharacter = source[index] | mark
                        consumedExtra = 1
                        hasCompoundCandidate = true
                    }

                default:
                    break
                }

                if hasCompoundCandidate,
                   tryConvertCharacter(
                       compoundCharacter,
                       options: options,
                       shouldUpperCase: shouldUpperCase,
                       output: &converted
                   ) {
                    index += consumedExtra + 1
                    shouldUpperCase = false
                    hasBreak = false
                    continue
                }
            }

            let singleCharacter = source[index]
            if tryConvertCharacter(
                singleCharacter,
                options: options,
                shouldUpperCase: shouldUpperCase,
                output: &converted
            ) {
                shouldUpperCase = false
                hasBreak = false
                index += 1
                continue
            }

            let forceUpperCase = options.toAllCaps || shouldUpperCase
            let forceLowerCase = options.toAllNonCaps || options.toCapsFirstLetter || options.toCapsEachWord

            if forceUpperCase {
                converted.append(uppercased(singleCharacter))
            } else if forceLowerCase {
                converted.append(lowercased(singleCharacter))
            } else {
                converted.append(singleCharacter)
            }

            if singleCharacter == 10 || (hasBreak && singleCharacter == 32) {
                if options.toCapsFirstLetter || options.toCapsEachWord {
                    shouldUpperCase = true
                }
            } else if singleCharacter == 32 && options.toCapsEachWord {
                shouldUpperCase = true
            } else if breakCodes.contains(singleCharacter) {
                hasBreak = true
            } else {
                shouldUpperCase = false
                hasBreak = false
            }

            index += 1
        }

        return String(decoding: converted, as: UTF16.self)
    }

    private class func tryConvertCharacter(
        _ sourceCharacter: UInt16,
        options: Options,
        shouldUpperCase: Bool,
        output: inout [UInt16]
    ) -> Bool {
        guard let (sourceKeyCode, sourceVariantIndex) = EngineCodeTableLookup.findSourceKey(
            codeTable: options.fromCode,
            character: sourceCharacter
        ) else {
            return false
        }

        var targetVariantIndex = sourceVariantIndex
        let forceUpperCase = options.toAllCaps || shouldUpperCase
        let forceLowerCase = options.toAllNonCaps || options.toCapsFirstLetter || options.toCapsEachWord
        let targetVariantCount = EngineCodeTableLookup.variantCount(
            codeTable: options.toCode,
            keyCode: sourceKeyCode
        )

        if forceUpperCase && (targetVariantIndex % 2 != 0) && targetVariantIndex > 0 {
            targetVariantIndex -= 1
        } else if forceLowerCase &&
                    (targetVariantIndex % 2 == 0) &&
                    (targetVariantIndex + 1) < targetVariantCount {
            targetVariantIndex += 1
        }

        guard var targetCharacter = EngineCodeTableLookup.characterForKey(
            codeTable: options.toCode,
            keyCode: sourceKeyCode,
            variantIndex: targetVariantIndex
        ) else {
            return false
        }

        if options.removeMark {
            let baseKeyCode = UInt32(UInt8(truncatingIfNeeded: sourceKeyCode))
            targetCharacter = EngineMacroKeyMap.character(for: baseKeyCode)
            if options.toAllCaps {
                targetCharacter = uppercased(targetCharacter)
            } else if options.toAllNonCaps {
                targetCharacter = lowercased(targetCharacter)
            }
        }

        appendTargetByCode(
            codeTable: options.toCode,
            targetCharacter: targetCharacter,
            output: &output
        )
        return true
    }

    private class func appendTargetByCode(
        codeTable: Int32,
        targetCharacter: UInt16,
        output: inout [UInt16]
    ) {
        switch codeTable {
        case Int32(CodeTable.unicode.toIndex()),
             Int32(CodeTable.tcvn.toIndex()):
            output.append(targetCharacter)

        case Int32(CodeTable.vniWindows.toIndex()),
             Int32(CodeTable.cp1258.toIndex()):
            let lowByte = targetCharacter & 0x00FF
            let highByte = (targetCharacter >> 8) & 0x00FF
            output.append(lowByte)
            if highByte > 32 {
                output.append(highByte)
            }

        case Int32(CodeTable.unicodeComposite.toIndex()):
            let markIndex = Int32(targetCharacter >> 13)
            if markIndex > 0 {
                output.append(targetCharacter & 0x1FFF)
                output.append(EnginePackedData.unicodeCompoundMark(at: markIndex - 1))
            } else {
                output.append(targetCharacter)
            }

        default:
            output.append(targetCharacter)
        }
    }

    private class func unicodeCompoundMarkIndex(for mark: UInt16) -> UInt16 {
        for index in 0..<5 {
            if mark == EnginePackedData.unicodeCompoundMark(at: Int32(index)) {
                return UInt16((index + 1) << 13)
            }
        }
        return 0
    }

    private class func uppercased(_ character: UInt16) -> UInt16 {
        transformCase(character, upper: true)
    }

    private class func lowercased(_ character: UInt16) -> UInt16 {
        transformCase(character, upper: false)
    }

    private class func transformCase(_ character: UInt16, upper: Bool) -> UInt16 {
        guard let scalar = UnicodeScalar(Int(character)) else {
            return character
        }
        let transformed = upper ? String(scalar).uppercased() : String(scalar).lowercased()
        guard transformed.utf16.count == 1, let value = transformed.utf16.first else {
            return character
        }
        return value
    }

    private class func snapshotOptions(defaults: UserDefaults) -> Options {
        var options = Options(
            toAllCaps: defaults.bool(forKey: keyToAllCaps),
            toAllNonCaps: defaults.bool(forKey: keyToAllNonCaps),
            toCapsFirstLetter: defaults.bool(forKey: keyToCapsFirstLetter),
            toCapsEachWord: defaults.bool(forKey: keyToCapsEachWord),
            removeMark: defaults.bool(forKey: keyRemoveMark),
            fromCode: sanitizeCodeTable(Int32(defaults.integer(forKey: keyFromCode))),
            toCode: sanitizeCodeTable(Int32(defaults.integer(forKey: keyToCode)))
        )

        if options.toAllCaps {
            options.toAllNonCaps = false
            options.toCapsFirstLetter = false
            options.toCapsEachWord = false
        } else if options.toAllNonCaps {
            options.toCapsFirstLetter = false
            options.toCapsEachWord = false
        }

        return options
    }

    private class func sanitizeCodeTable(_ codeTable: Int32) -> Int32 {
        guard codeTable >= minCodeTable, codeTable <= maxCodeTable else {
            return defaultCodeTable
        }
        return codeTable
    }
}
