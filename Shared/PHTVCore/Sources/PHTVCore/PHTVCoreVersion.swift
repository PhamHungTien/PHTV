public enum PHTVCoreVersion {
    public static let abi: UInt32 = 1
}

public struct PHTVCoreCapabilities: OptionSet, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static let sessionABI = Self(rawValue: 1 << 0)
    public static let telexEngine = Self(rawValue: 1 << 1)
    public static let vniEngine = Self(rawValue: 1 << 2)
    public static let vietnameseEngine: Self = [.telexEngine, .vniEngine]

    public static let current: Self = [.sessionABI, .telexEngine, .vniEngine]
}
