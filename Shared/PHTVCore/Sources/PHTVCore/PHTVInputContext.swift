public enum PHTVLanguageMode: UInt32, Sendable {
    case english = 0
    case vietnamese = 1
}

public enum PHTVInputMethod: UInt32, Sendable {
    case telex = 0
    case vni = 1
}

public enum PHTVAppRule: UInt32, Sendable {
    case inherit = 0
    case preferEnglish = 1
    case lockEnglish = 2
}

public struct PHTVInputContextFlags: OptionSet, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static let supportsComposition = Self(rawValue: 1 << 0)
    public static let supportsSurroundingText = Self(rawValue: 1 << 1)
    public static let sensitive = Self(rawValue: 1 << 2)
    public static let terminal = Self(rawValue: 1 << 3)
}

public struct PHTVInputContext: Equatable, Sendable {
    public let languageMode: PHTVLanguageMode
    public let appRule: PHTVAppRule
    public let inputMethod: PHTVInputMethod
    public let flags: PHTVInputContextFlags

    public init(
        languageMode: PHTVLanguageMode,
        appRule: PHTVAppRule = .inherit,
        inputMethod: PHTVInputMethod = .telex,
        flags: PHTVInputContextFlags = []
    ) {
        self.languageMode = languageMode
        self.appRule = appRule
        self.inputMethod = inputMethod
        self.flags = flags
    }
}
