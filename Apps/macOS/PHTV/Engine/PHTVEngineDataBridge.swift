//
//  PHTVEngineDataBridge.swift
//  PHTV
//
//  Swift facade for engine data/dictionary APIs.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

private func phtvCallClearCustomDictionary() {
    phtvCustomDictionaryClear()
}

private func phtvCallStartNewSession() {
    phtvEngineStartNewSession()
}

@objcMembers
final class PHTVEngineDataBridge: NSObject {
    class func initializeMacroMap(with data: Data) {
        data.withUnsafeBytes { rawBuffer in
            let base = rawBuffer.bindMemory(to: UInt8.self).baseAddress
            phtvLoadMacroMapFromBinary(base, Int32(rawBuffer.count))
        }
    }

    class func initializeEnglishDictionary(atPath path: String) -> Bool {
        return path.withCString { cPath in
            guard cPath[0] != 0 else {
                return false
            }
            return phtvDictionaryInitEnglish(cPath) != 0
        }
    }

    class func englishDictionarySize() -> UInt {
        return UInt(phtvDictionaryEnglishWordCount())
    }

    class func initializeVietnameseDictionary(atPath path: String) -> Bool {
        return path.withCString { cPath in
            guard cPath[0] != 0 else {
                return false
            }
            return phtvDictionaryInitVietnamese(cPath) != 0
        }
    }

    class func vietnameseDictionarySize() -> UInt {
        return UInt(phtvDictionaryVietnameseWordCount())
    }

    class func initializeCustomDictionary(withJSONData jsonData: Data) {
        jsonData.withUnsafeBytes { rawBuffer in
            let base = rawBuffer.bindMemory(to: CChar.self).baseAddress
            phtvCustomDictionaryLoadJSON(base, Int32(rawBuffer.count))
        }
    }

    class func customEnglishWordCount() -> UInt {
        return UInt(phtvCustomDictionaryEnglishCount())
    }

    class func customVietnameseWordCount() -> UInt {
        return UInt(phtvCustomDictionaryVietnameseCount())
    }

    class func clearCustomDictionary() {
        phtvCallClearCustomDictionary()
    }

    class func startNewSession() {
        phtvCallStartNewSession()
    }

    class func macroString(
        fromMacroData macroData: [UInt32],
        codeTable: Int32
    ) -> String {
        guard !macroData.isEmpty else {
            return ""
        }

        let charCodeMask = EngineBitMask.charCode
        let pureCharacterMask = EngineBitMask.pureCharacter

        var result = String()
        for data in macroData {
            if (data & pureCharacterMask) != 0 {
                let scalarValue = data & ~pureCharacterMask
                if let scalar = UnicodeScalar(scalarValue) {
                    result.unicodeScalars.append(scalar)
                }
                continue
            }

            if (data & charCodeMask) == 0 {
                let character = EngineMacroKeyMap.character(for: data)
                if character != 0 {
                    result.append(String(decoding: [character], as: UTF16.self))
                }
                continue
            }

            switch codeTable {
            case Int32(CodeTable.unicode.toIndex()):
                result.append(String(decoding: [UInt16(truncatingIfNeeded: data)], as: UTF16.self))
            case Int32(CodeTable.tcvn.toIndex()),
                 Int32(CodeTable.vniWindows.toIndex()),
                 Int32(CodeTable.cp1258.toIndex()):
                let low = EnginePackedData.lowByte(data)
                let high = EnginePackedData.highByte(data)
                result.append(String(decoding: [low], as: UTF16.self))
                if high > 32 {
                    result.append(String(decoding: [high], as: UTF16.self))
                }
            case Int32(CodeTable.unicodeComposite.toIndex()):
                var character = UInt16(truncatingIfNeeded: data)
                let markIndex = character >> 13
                character &= 0x1FFF
                result.append(String(decoding: [character], as: UTF16.self))
                if markIndex > 0 {
                    let mark = EnginePackedData.unicodeCompoundMark(at: Int32(markIndex) - 1)
                    result.append(String(decoding: [mark], as: UTF16.self))
                }
            default:
                continue
            }
        }

        return result
    }
}
