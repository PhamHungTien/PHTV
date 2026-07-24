import PHTVCoreContracts

private enum CABI {
    static let ok: Int32 = 0
    static let invalidArgument: Int32 = 1
    static let unsupportedABI: Int32 = 2
}

@c(phtv_core_abi_version)
public func phtvCoreABIVersion() -> UInt32 {
    PHTVCoreVersion.abi
}

@c(phtv_core_capabilities)
public func phtvCoreCapabilities() -> UInt64 {
    PHTVCoreCapabilities.current.rawValue
}

@c(phtv_core_key_event_size)
public func phtvCoreKeyEventSize() -> Int {
    MemoryLayout<phtv_core_key_event_t>.size
}

@c(phtv_core_input_context_size)
public func phtvCoreInputContextSize() -> Int {
    MemoryLayout<phtv_core_input_context_t>.size
}

@c(phtv_core_edit_plan_size)
public func phtvCoreEditPlanSize() -> Int {
    MemoryLayout<phtv_core_edit_plan_t>.size
}

@c(phtv_core_session_create)
public func phtvCoreSessionCreate(
    _ outSession: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> Int32 {
    guard let outSession else {
        return CABI.invalidArgument
    }

    let session = PHTVCoreSession()
    outSession.pointee = Unmanaged.passRetained(session).toOpaque()
    return CABI.ok
}

@c(phtv_core_session_destroy)
public func phtvCoreSessionDestroy(
    _ session: UnsafeMutableRawPointer?
) -> Int32 {
    guard let session else {
        return CABI.invalidArgument
    }

    Unmanaged<PHTVCoreSession>.fromOpaque(session).release()
    return CABI.ok
}

@c(phtv_core_session_reset)
public func phtvCoreSessionReset(
    _ session: UnsafeMutableRawPointer?
) -> Int32 {
    guard let session else {
        return CABI.invalidArgument
    }

    Unmanaged<PHTVCoreSession>.fromOpaque(session)
        .takeUnretainedValue()
        .reset()
    return CABI.ok
}

@c(phtv_core_session_handle_event)
public func phtvCoreSessionHandleEvent(
    _ session: UnsafeMutableRawPointer?,
    _ event: UnsafePointer<phtv_core_key_event_t>?,
    _ context: UnsafePointer<phtv_core_input_context_t>?,
    _ outPlan: UnsafeMutablePointer<phtv_core_edit_plan_t>?,
    _ replacementUTF16: UnsafeMutablePointer<UInt16>?,
    _ replacementCapacityUTF16: Int
) -> Int32 {
    guard
        let session,
        let event,
        let context,
        let outPlan
    else {
        return CABI.invalidArgument
    }

    guard
        event.pointee.struct_size >= MemoryLayout<phtv_core_key_event_t>.size,
        context.pointee.struct_size >= MemoryLayout<phtv_core_input_context_t>.size,
        outPlan.pointee.struct_size >= MemoryLayout<phtv_core_edit_plan_t>.size
    else {
        return CABI.unsupportedABI
    }

    guard replacementCapacityUTF16 == 0 || replacementUTF16 != nil else {
        return CABI.invalidArgument
    }

    guard
        let eventKind = PHTVKeyEventKind(rawValue: event.pointee.kind),
        let languageMode = PHTVLanguageMode(rawValue: context.pointee.language_mode),
        let appRule = PHTVAppRule(rawValue: context.pointee.app_rule)
    else {
        return CABI.invalidArgument
    }

    let scalar =
        event.pointee.logical_scalar == 0
        ? nil
        : Unicode.Scalar(event.pointee.logical_scalar)
    guard event.pointee.logical_scalar == 0 || scalar != nil else {
        return CABI.invalidArgument
    }

    let swiftEvent = PHTVKeyEvent(
        kind: eventKind,
        hardwareUsage: event.pointee.hardware_key,
        logicalScalar: scalar,
        modifiers: PHTVKeyModifiers(rawValue: event.pointee.modifiers),
        isRepeat: event.pointee.is_repeat != 0
    )
    let swiftContext = PHTVInputContext(
        languageMode: languageMode,
        appRule: appRule,
        flags: PHTVInputContextFlags(rawValue: context.pointee.flags)
    )
    let coreSession = Unmanaged<PHTVCoreSession>
        .fromOpaque(session)
        .takeUnretainedValue()
    let plan = coreSession.handle(event: swiftEvent, context: swiftContext)

    outPlan.pointee.action = plan.action.rawValue
    outPlan.pointee.delete_before_utf16 = plan.deleteBeforeUTF16
    outPlan.pointee.delete_after_utf16 = plan.deleteAfterUTF16
    outPlan.pointee.replacement_length_utf16 = UInt32(plan.replacement.utf16.count)
    outPlan.pointee.reserved0 = 0
    outPlan.pointee.flags = plan.flags.rawValue
    outPlan.pointee.session_generation = plan.sessionGeneration
    outPlan.pointee.reserved = (0, 0)

    return CABI.ok
}
