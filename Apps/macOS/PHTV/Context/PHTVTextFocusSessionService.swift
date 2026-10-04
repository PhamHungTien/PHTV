import AppKit
import ApplicationServices
import Foundation
import os

/// A focus boundary is independent of a word boundary: timeline shortcuts must
/// never become the prefix of text entered into a marker's name or notes.
struct PHTVTextFocusSessionState<Focus: Equatable> {
    private var previousFocus: Focus?
    private var previousEditable: Bool?

    mutating func update(focus: Focus?, editable: Bool?) -> (reset: Bool, bypass: Bool) {
        // A failed AX read is not evidence that a text editor lost focus.
        guard let focus else { return (false, false) }
        let focusChanged = previousFocus != focus
        let editabilityChanged = editable != nil && previousEditable != nil && previousEditable != editable
        previousFocus = focus
        if focusChanged || editable != nil {
            previousEditable = editable
        }
        // Unknown roles still establish a focus boundary, but cannot justify
        // disabling composition in a custom editor.
        return (focusChanged || editabilityChanged, editable == false)
    }
}

enum PHTVTextFocusEvidence {
    static func editable(role: String, hasTextSelection: Bool) -> Bool? {
        if hasTextSelection || [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) {
            return true
        }
        // Final Cut's timeline exposes AXLayoutArea/AXLayoutItem. Do not
        // infer non-editability for generic groups, windows or unknown roles.
        if ["AXLayoutArea", "AXLayoutItem", kAXButtonRole, kAXCheckBoxRole,
            kAXRadioButtonRole, kAXMenuItemRole, kAXSliderRole].contains(role) {
            return false
        }
        return nil
    }
}

struct PHTVFocusReadBudget {
    let startedAt: TimeInterval
    static let maximumSeconds: TimeInterval = 0.01

    func remaining(at now: TimeInterval) -> Float? {
        let remaining = Self.maximumSeconds - max(0, now - startedAt)
        // Zero would restore AX's default timeout, rather than prevent a read.
        return remaining > 0 ? Float(remaining) : nil
    }
}

enum PHTVTextFocusSessionService {
    private struct Focus: Equatable {
        let pid: pid_t
        let element: AXUIElement

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.pid == rhs.pid && CFEqual(lhs.element, rhs.element)
        }
    }

    private struct State {
        var session = PHTVTextFocusSessionState<Focus>()
        var generation: UInt64 = 0
    }

    // AX references never leave this lock's state; IPC runs outside the lock.
    private static let state = OSAllocatedUnfairLock(uncheckedState: State())

    static func isSupported(bundleId: String?) -> Bool {
        bundleId?.lowercased() == "com.apple.finalcut"
    }

    static func clear() {
        state.withLockUnchecked {
            $0.session = PHTVTextFocusSessionState()
            $0.generation &+= 1
        }
    }

    /// Called only for real keydowns, before either the Vietnamese or English
    /// macro engine sees them. No text content is read or retained.
    static func transition(bundleId: String?, pid: pid_t, safeMode: Bool) -> (reset: Bool, bypass: Bool) {
        guard isSupported(bundleId: bundleId), !safeMode else {
            clear()
            return (false, false)
        }
        let generation = state.withLockUnchecked { $0.generation }
        let budget = PHTVFocusReadBudget(startedAt: ProcessInfo.processInfo.systemUptime)
        func prepareRead(_ element: AXUIElement) -> Bool {
            guard let remaining = budget.remaining(at: ProcessInfo.processInfo.systemUptime) else { return false }
            return AXUIElementSetMessagingTimeout(element, remaining) == .success
        }
        var pid = pid
        if pid <= 0 {
            guard let frontmost = NSWorkspace.shared.frontmostApplication,
                  isSupported(bundleId: frontmost.bundleIdentifier) else { return (false, false) }
            pid = frontmost.processIdentifier
        }
        let app = AXUIElementCreateApplication(pid)
        // Never wait for the default AX timeout on the keyboard event thread.
        guard prepareRead(app) else {
            return (false, false)
        }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return (false, false)
        }
        let element = unsafeBitCast(value, to: AXUIElement.self)
        guard prepareRead(element) else {
            return (false, false)
        }
        var roleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success,
              let role = roleValue as? String else { return (false, false) }
        var editable = PHTVTextFocusEvidence.editable(role: role, hasTextSelection: false)
        if editable != true {
            // A custom editor may expose a text selection despite its role.
            // Spend only the remaining portion of this key's AX budget.
            if prepareRead(element) {
                var selection: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selection)
                if result == .success, let selection,
                   CFGetTypeID(selection) == AXValueGetTypeID(),
                   AXValueGetType(unsafeBitCast(selection, to: AXValue.self)) == .cfRange {
                    editable = true
                } else if result != .attributeUnsupported && result != .noValue {
                    editable = nil
                }
            } else {
                editable = nil
            }
        }
        return state.withLockUnchecked {
            // App/lifecycle changes can invalidate focus while AX is answering.
            guard $0.generation == generation else { return (false, false) }
            return $0.session.update(focus: Focus(pid: pid, element: element), editable: editable)
        }
    }
}
