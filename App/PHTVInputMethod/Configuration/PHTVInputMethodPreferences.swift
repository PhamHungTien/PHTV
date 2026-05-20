import Foundation

enum PHTVInputStyle: Int, CaseIterable {
    case telex = 0
    case vni = 1
    case simpleTelex1 = 2
    case simpleTelex2 = 3

    var displayName: String {
        switch self {
        case .telex:
            return "Telex"
        case .vni:
            return "VNI"
        case .simpleTelex1:
            return "Simple Telex 1"
        case .simpleTelex2:
            return "Simple Telex 2"
        }
    }
}

enum PHTVOutputEncoding: Int, CaseIterable {
    case unicode = 0
    case tcvn3 = 1
    case vniWindows = 2
    case unicodeComposite = 3
    case cp1258 = 4

    var displayName: String {
        switch self {
        case .unicode:
            return "Unicode"
        case .tcvn3:
            return "TCVN3"
        case .vniWindows:
            return "VNI Windows"
        case .unicodeComposite:
            return "Unicode Composite"
        case .cp1258:
            return "Vietnamese Locale CP1258"
        }
    }
}

struct PHTVInputMethodConfiguration {
    var inputStyle: PHTVInputStyle
    var outputEncoding: PHTVOutputEncoding
    var autoRestoreEnglishWord: Bool
    var upperCaseFirstChar: Bool

    init(
        inputStyle: PHTVInputStyle,
        outputEncoding: PHTVOutputEncoding,
        autoRestoreEnglishWord: Bool = true,
        upperCaseFirstChar: Bool = false
    ) {
        self.inputStyle = inputStyle
        self.outputEncoding = outputEncoding
        self.autoRestoreEnglishWord = autoRestoreEnglishWord
        self.upperCaseFirstChar = upperCaseFirstChar
    }

    static let fallback = PHTVInputMethodConfiguration(
        inputStyle: .telex,
        outputEncoding: .unicode,
        autoRestoreEnglishWord: true,
        upperCaseFirstChar: false
    )
}

enum PHTVInputMethodPreferences {
    private static let inputMethodKey = "InputType"
    private static let codeTableKey = "CodeTable"
    private static let autoRestoreEnglishWordKey = "vAutoRestoreEnglishWord"
    private static let upperCaseFirstCharKey = "UpperCaseFirstChar"
    private static let preferenceDomains = [
        "com.phamhungtien.phtv.inputmethod",
        "com.phamhungtien.phtv",
        "com.phamhungtien.phtv.debug",
    ]

    static func currentConfiguration() -> PHTVInputMethodConfiguration {
        var inputMethodValue = UserDefaults.standard.object(forKey: inputMethodKey) as? Int
        var codeTableValue = UserDefaults.standard.object(forKey: codeTableKey) as? Int
        var autoRestoreValue = UserDefaults.standard.object(forKey: autoRestoreEnglishWordKey) as? Bool
        var upperCaseValue = UserDefaults.standard.object(forKey: upperCaseFirstCharKey) as? Bool

        for domain in preferenceDomains where inputMethodValue == nil || codeTableValue == nil || autoRestoreValue == nil || upperCaseValue == nil {
            guard let defaults = UserDefaults(suiteName: domain) else { continue }
            if inputMethodValue == nil {
                inputMethodValue = defaults.object(forKey: inputMethodKey) as? Int
            }
            if codeTableValue == nil {
                codeTableValue = defaults.object(forKey: codeTableKey) as? Int
            }
            if autoRestoreValue == nil {
                autoRestoreValue = defaults.object(forKey: autoRestoreEnglishWordKey) as? Bool
            }
            if upperCaseValue == nil {
                upperCaseValue = defaults.object(forKey: upperCaseFirstCharKey) as? Bool
            }
        }

        return PHTVInputMethodConfiguration(
            inputStyle: PHTVInputStyle(rawValue: inputMethodValue ?? PHTVInputMethodConfiguration.fallback.inputStyle.rawValue)
                ?? PHTVInputMethodConfiguration.fallback.inputStyle,
            outputEncoding: PHTVOutputEncoding(rawValue: codeTableValue ?? PHTVInputMethodConfiguration.fallback.outputEncoding.rawValue)
                ?? PHTVInputMethodConfiguration.fallback.outputEncoding,
            autoRestoreEnglishWord: autoRestoreValue ?? PHTVInputMethodConfiguration.fallback.autoRestoreEnglishWord,
            upperCaseFirstChar: upperCaseValue ?? PHTVInputMethodConfiguration.fallback.upperCaseFirstChar
        )
    }

    static func saveConfiguration(_ config: PHTVInputMethodConfiguration) {
        let domain = "com.phamhungtien.phtv"
        
        // Write to App Suite defaults
        if let defaults = UserDefaults(suiteName: domain) {
            defaults.set(config.inputStyle.rawValue, forKey: "InputType")
            defaults.set(config.outputEncoding.rawValue, forKey: "CodeTable")
            defaults.set(config.autoRestoreEnglishWord, forKey: autoRestoreEnglishWordKey)
            defaults.set(config.upperCaseFirstChar, forKey: upperCaseFirstCharKey)
            defaults.synchronize()
        }
        
        // Write to standard defaults
        UserDefaults.standard.set(config.inputStyle.rawValue, forKey: "InputType")
        UserDefaults.standard.set(config.outputEncoding.rawValue, forKey: "CodeTable")
        UserDefaults.standard.set(config.autoRestoreEnglishWord, forKey: autoRestoreEnglishWordKey)
        UserDefaults.standard.set(config.upperCaseFirstChar, forKey: upperCaseFirstCharKey)
        UserDefaults.standard.synchronize()
        
        // Post notifications
        NotificationCenter.default.post(
            name: NSNotification.Name("InputMethodChanged"),
            object: NSNumber(value: config.inputStyle.rawValue)
        )
        NotificationCenter.default.post(
            name: NSNotification.Name("CodeTableChanged"),
            object: NSNumber(value: config.outputEncoding.rawValue)
        )
        NotificationCenter.default.post(
            name: NSNotification.Name("vAutoRestoreEnglishWordChanged"),
            object: NSNumber(value: config.autoRestoreEnglishWord)
        )
        NotificationCenter.default.post(
            name: NSNotification.Name("UpperCaseFirstCharChanged"),
            object: NSNumber(value: config.upperCaseFirstChar)
        )
        NotificationCenter.default.post(
            name: NSNotification.Name("PHTVSettingsChanged"),
            object: nil
        )
    }
}
