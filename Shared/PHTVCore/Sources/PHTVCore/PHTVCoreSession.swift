public final class PHTVCoreSession {
    public private(set) var generation: UInt64 = 1

    public init() {}

    public func reset() {
        generation &+= 1
        if generation == 0 {
            generation = 1
        }
    }

    public func handle(
        event: PHTVKeyEvent,
        context: PHTVInputContext
    ) -> PHTVEditPlan {
        _ = event
        _ = context

        // The first portable increment establishes the stable session contract.
        // Vietnamese transformation moves here only after macOS golden vectors
        // protect behavior parity.
        return PHTVEditPlan(
            action: .passThrough,
            sessionGeneration: generation
        )
    }
}
