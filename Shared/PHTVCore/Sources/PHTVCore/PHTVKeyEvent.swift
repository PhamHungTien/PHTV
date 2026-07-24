public enum PHTVKeyEventKind: UInt32, Sendable {
    case keyDown = 1
    case keyUp = 2
}

public struct PHTVKeyModifiers: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let shift = Self(rawValue: 1 << 0)
    public static let control = Self(rawValue: 1 << 1)
    public static let alt = Self(rawValue: 1 << 2)
    public static let command = Self(rawValue: 1 << 3)
    public static let capsLock = Self(rawValue: 1 << 4)
}

public struct PHTVKeyEvent: Equatable, Sendable {
    public let kind: PHTVKeyEventKind
    public let hardwareUsage: UInt32
    public let logicalScalar: Unicode.Scalar?
    public let modifiers: PHTVKeyModifiers
    public let isRepeat: Bool

    public init(
        kind: PHTVKeyEventKind,
        hardwareUsage: UInt32,
        logicalScalar: Unicode.Scalar?,
        modifiers: PHTVKeyModifiers = [],
        isRepeat: Bool = false
    ) {
        self.kind = kind
        self.hardwareUsage = hardwareUsage
        self.logicalScalar = logicalScalar
        self.modifiers = modifiers
        self.isRepeat = isRepeat
    }
}
