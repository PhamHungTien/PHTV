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

    static let fallback = PHTVInputMethodConfiguration(
        inputStyle: .telex,
        outputEncoding: .unicode
    )
}

enum PHTVInputMethodPreferences {
    private static let inputMethodKey = "InputMethod"
    private static let codeTableKey = "CodeTable"
    private static let preferenceDomains = [
        "com.phamhungtien.phtv.inputmethod",
        "com.phamhungtien.phtv",
        "com.phamhungtien.phtv.debug",
    ]

    static func currentConfiguration() -> PHTVInputMethodConfiguration {
        var inputMethodValue = UserDefaults.standard.object(forKey: inputMethodKey) as? Int
        var codeTableValue = UserDefaults.standard.object(forKey: codeTableKey) as? Int

        for domain in preferenceDomains where inputMethodValue == nil || codeTableValue == nil {
            guard let defaults = UserDefaults(suiteName: domain) else { continue }
            if inputMethodValue == nil {
                inputMethodValue = defaults.object(forKey: inputMethodKey) as? Int
            }
            if codeTableValue == nil {
                codeTableValue = defaults.object(forKey: codeTableKey) as? Int
            }
        }

        return PHTVInputMethodConfiguration(
            inputStyle: PHTVInputStyle(rawValue: inputMethodValue ?? PHTVInputMethodConfiguration.fallback.inputStyle.rawValue)
                ?? PHTVInputMethodConfiguration.fallback.inputStyle,
            outputEncoding: PHTVOutputEncoding(rawValue: codeTableValue ?? PHTVInputMethodConfiguration.fallback.outputEncoding.rawValue)
                ?? PHTVInputMethodConfiguration.fallback.outputEncoding
        )
    }
}
