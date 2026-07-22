//
//  PHTVCarbonHotkeyRegistration.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Carbon

final class PHTVCarbonHotkeyRegistration {
    private let signature: OSType
    private let registrationID: UInt32
    private let handler: @Sendable () -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(
        signature: OSType,
        registrationID: UInt32 = 1,
        handler: @escaping @Sendable () -> Void
    ) {
        self.signature = signature
        self.registrationID = registrationID
        self.handler = handler
    }

    func register(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> Bool {
        unregister()

        guard Self.canRegisterWithCarbon(modifiers: modifiers, keyCode: keyCode) else {
            return false
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard handlerStatus == noErr else {
            unregister()
            return false
        }

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: registrationID)
        let registrationStatus = RegisterEventHotKey(
            UInt32(keyCode),
            Self.carbonModifiers(from: modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registrationStatus == noErr, let hotKeyRef else {
            unregister()
            return false
        }

        self.hotKeyRef = hotKeyRef
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    static func canRegisterWithCarbon(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> Bool {
        guard keyCode != KeyCode.noKey, keyCode <= KeyCode.keyMask else {
            return false
        }

        let filteredModifiers = modifiers.intersection([.command, .option, .control, .shift])
        guard !filteredModifiers.isEmpty else {
            return false
        }

        // Carbon hotkeys do not reliably own Fn-based combos, so we keep those on the monitor fallback.
        return !modifiers.contains(.function)
    }

    private static func carbonModifiers(from modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        return carbonModifiers
    }

    private func handleHotkeyEvent(_ eventRef: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr,
              hotKeyID.signature == signature,
              hotKeyID.id == registrationID else {
            return OSStatus(eventNotHandledErr)
        }

        handler()
        return noErr
    }

    private static let eventHandler: EventHandlerUPP = { _, eventRef, userData in
        guard let eventRef, let userData else {
            return OSStatus(eventNotHandledErr)
        }

        let registration = Unmanaged<PHTVCarbonHotkeyRegistration>
            .fromOpaque(userData)
            .takeUnretainedValue()
        return registration.handleHotkeyEvent(eventRef)
    }
}
