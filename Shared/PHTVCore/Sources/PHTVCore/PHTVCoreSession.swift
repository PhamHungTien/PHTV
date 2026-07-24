public final class PHTVCoreSession {
    public private(set) var generation: UInt64 = 1
    private var compositionEngine = PHTVCompositionEngine()

    public init() {}

    public func reset() {
        compositionEngine.reset()
        generation &+= 1
        if generation == 0 {
            generation = 1
        }
    }

    public func handle(
        event: PHTVKeyEvent,
        context: PHTVInputContext
    ) -> PHTVEditPlan {
        guard context.languageMode == .vietnamese,
            context.appRule != .lockEnglish,
            !context.flags.contains(.sensitive)
        else {
            compositionEngine.reset()
            return passThroughPlan()
        }

        guard event.kind == .keyDown else {
            return passThroughPlan()
        }

        let shortcutModifiers: PHTVKeyModifiers = [.control, .alt, .command]
        guard event.modifiers.intersection(shortcutModifiers).isEmpty else {
            compositionEngine.reset()
            return passThroughPlan()
        }

        let change: PHTVCompositionChange
        if event.hardwareUsage == 0x2A {
            change = compositionEngine.handleBackspace(method: context.inputMethod)
        } else if let scalar = event.logicalScalar {
            change = compositionEngine.handle(
                scalar: scalar,
                method: context.inputMethod
            )
        } else {
            compositionEngine.reset()
            return passThroughPlan()
        }

        switch change {
        case .passThrough:
            return passThroughPlan()
        case let .replace(previous, replacement):
            return PHTVEditPlan(
                action: .replace,
                deleteBeforeUTF16: UInt32(previous.utf16.count),
                replacement: replacement,
                flags: [.consumesKey],
                sessionGeneration: generation
            )
        }
    }

    func checkpoint() -> PHTVCoreSessionCheckpoint {
        PHTVCoreSessionCheckpoint(compositionEngine: compositionEngine)
    }

    func restore(_ checkpoint: PHTVCoreSessionCheckpoint) {
        compositionEngine = checkpoint.compositionEngine
    }

    private func passThroughPlan() -> PHTVEditPlan {
        PHTVEditPlan(
            action: .passThrough,
            sessionGeneration: generation
        )
    }
}

struct PHTVCoreSessionCheckpoint {
    let compositionEngine: PHTVCompositionEngine
}
