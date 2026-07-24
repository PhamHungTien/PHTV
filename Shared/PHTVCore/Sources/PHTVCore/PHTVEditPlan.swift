public enum PHTVEditAction: UInt32, Sendable {
    case passThrough = 0
    case replace = 1
    case commit = 2
    case resetSession = 3
}

public struct PHTVEditFlags: OptionSet, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static let consumesKey = Self(rawValue: 1 << 0)
    public static let endsComposition = Self(rawValue: 1 << 1)
}

public struct PHTVEditPlan: Equatable, Sendable {
    public let action: PHTVEditAction
    public let deleteBeforeUTF16: UInt32
    public let deleteAfterUTF16: UInt32
    public let replacement: String
    public let flags: PHTVEditFlags
    public let sessionGeneration: UInt64

    public init(
        action: PHTVEditAction,
        deleteBeforeUTF16: UInt32 = 0,
        deleteAfterUTF16: UInt32 = 0,
        replacement: String = "",
        flags: PHTVEditFlags = [],
        sessionGeneration: UInt64
    ) {
        self.action = action
        self.deleteBeforeUTF16 = deleteBeforeUTF16
        self.deleteAfterUTF16 = deleteAfterUTF16
        self.replacement = replacement
        self.flags = flags
        self.sessionGeneration = sessionGeneration
    }
}
