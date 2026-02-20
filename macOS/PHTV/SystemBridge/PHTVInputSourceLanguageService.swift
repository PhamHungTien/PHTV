//
//  PHTVInputSourceLanguageService.swift
//  PHTV
//
//  Shared input-source language detection for Swift and ObjC++ call sites.
//

import Carbon
import Darwin
import Foundation

final class PHTVInputSourceLanguageService: NSObject {
    private static let languageCacheRefreshMs: UInt64 = 1000

    nonisolated(unsafe) private static var languageCacheLock = NSLock()
    nonisolated(unsafe) private static var cachedPrimaryLanguage: String?
    nonisolated(unsafe) private static var lastLanguageCheckTime: UInt64 = 0

    private static let nonLatinInputSourcePatterns: [String] = [
        "com.apple.inputmethod.Kotoeri", "com.apple.inputmethod.Japanese",
        "com.google.inputmethod.Japanese", "jp.co.atok",
        "com.apple.inputmethod.SCIM", "com.apple.inputmethod.TCIM",
        "com.apple.inputmethod.ChineseHandwriting",
        "com.sogou.inputmethod", "com.baidu.inputmethod",
        "com.tencent.inputmethod", "com.iflytek.inputmethod",
        "com.apple.inputmethod.Korean", "com.apple.inputmethod.KoreanIM",
        "com.apple.keylayout.Arabic", "com.apple.keylayout.ArabicPC",
        "com.apple.keylayout.Hebrew", "com.apple.keylayout.HebrewQWERTY",
        "com.apple.keylayout.Thai", "com.apple.keylayout.ThaiPattachote",
        "com.apple.keylayout.Devanagari", "com.apple.keylayout.Hindi",
        "com.apple.inputmethod.Hindi",
        "com.apple.keylayout.Greek", "com.apple.keylayout.GreekPolytonic",
        "com.apple.keylayout.Russian", "com.apple.keylayout.RussianPC",
        "com.apple.keylayout.Ukrainian", "com.apple.keylayout.Bulgarian",
        "com.apple.keylayout.Serbian", "com.apple.keylayout.Macedonian",
        "com.apple.keylayout.Georgian",
        "com.apple.keylayout.Armenian",
        "com.apple.keylayout.Tamil", "com.apple.keylayout.Telugu",
        "com.apple.keylayout.Kannada", "com.apple.keylayout.Malayalam",
        "com.apple.keylayout.Gujarati", "com.apple.keylayout.Punjabi",
        "com.apple.keylayout.Bengali", "com.apple.keylayout.Oriya",
        "com.apple.keylayout.Myanmar", "com.apple.keylayout.Khmer",
        "com.apple.keylayout.Lao",
        "com.apple.keylayout.Tibetan", "com.apple.keylayout.Nepali",
        "com.apple.keylayout.Sinhala",
        "com.apple.CharacterPaletteIM", "com.apple.PressAndHold",
        "com.apple.inputmethod.EmojiFunctionRowItem"
    ]

    private static let latinLanguages: Set<String> = [
        "en", "de", "fr", "es", "it", "pt", "nl", "ca",
        "da", "sv", "no", "nb", "nn", "fi", "is", "fo",
        "pl", "cs", "sk", "hu", "ro", "hr", "sl", "sr-Latn",
        "et", "lv", "lt",
        "sq", "bs", "mt",
        "tr", "az", "uz", "tk",
        "id", "ms", "vi", "tl", "jv", "su",
        "sw", "ha", "yo", "ig", "zu", "xh", "af",
        "mi", "sm", "to", "haw",
        "ga", "gd", "cy", "br",
        "eo", "la", "mul"
    ]

    @inline(__always)
    private class func inputSourceProperty(_ inputSource: TISInputSource, _ key: CFString) -> AnyObject? {
        guard let rawValue = TISGetInputSourceProperty(inputSource, key) else {
            return nil
        }
        return Unmanaged<AnyObject>.fromOpaque(rawValue).takeUnretainedValue()
    }

    class func isLatinInputSource(_ inputSource: TISInputSource?) -> Bool {
        guard let inputSource else {
            return true
        }

        let sourceID = inputSourceProperty(inputSource, kTISPropertyInputSourceID) as? String
        if let sourceID {
            for pattern in nonLatinInputSourcePatterns where sourceID.contains(pattern) {
                return false
            }
        }

        let languages = inputSourceProperty(inputSource, kTISPropertyInputSourceLanguages) as? [String]
        guard let language = languages?.first else {
            return true
        }

        return latinLanguages.contains(language)
    }

    @objc(shouldAllowVietnameseForOtherLanguageMode)
    class func shouldAllowVietnameseForOtherLanguageMode() -> Bool {
        let language = primaryLanguageWithCaching()
        guard let language else {
            return true
        }
        return latinLanguages.contains(language)
    }

    private class func primaryLanguageWithCaching() -> String? {
        let now = mach_absolute_time()

        languageCacheLock.lock()
        let lastCheck = lastLanguageCheckTime
        let cached = cachedPrimaryLanguage
        languageCacheLock.unlock()

        if lastCheck > 0 {
            let elapsedMs = PHTVTimingService.machTimeToMs(now - lastCheck)
            if elapsedMs <= languageCacheRefreshMs {
                return cached
            }
        }

        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return cached
        }

        let languages = inputSourceProperty(inputSource, kTISPropertyInputSourceLanguages) as? [String]
        let refreshedLanguage = languages?.first

        languageCacheLock.lock()
        if let refreshedLanguage {
            cachedPrimaryLanguage = refreshedLanguage
        }
        lastLanguageCheckTime = now
        let resolved = cachedPrimaryLanguage
        languageCacheLock.unlock()

        return resolved
    }
}
