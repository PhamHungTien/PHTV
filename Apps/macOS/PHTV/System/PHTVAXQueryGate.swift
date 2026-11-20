//
//  PHTVAXQueryGate.swift
//  PHTV
//
//  Decides whether PHTV may send an Accessibility query right now.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import ApplicationServices
import Darwin

/// Accessibility queries are only ever aimed at other apps.
///
/// When a PHTV window (Settings, onboarding, Picker) is focused, the system-wide
/// "focused element" belongs to PHTV itself. An AX request to our own process is
/// answered in-process by AppKit, on whichever thread sent it. Coming from the
/// event-tap thread that walks SwiftUI's accessibility tree off the main thread
/// and crashes (EXC_BREAKPOINT in `NSAccessibilityChildren`, or EXC_BAD_ACCESS in
/// `_accessibilityConvenienceSupportedAttributes`). PHTV never needs AX context
/// for its own windows, so those queries are skipped.
enum PHTVAXQueryGate {
    private static let ownPID = getpid()

    /// True when `element` may be queried, i.e. it does not belong to PHTV.
    static func canQuery(_ element: AXUIElement) -> Bool {
        var pid: pid_t = 0
        if AXUIElementGetPid(element, &pid) == .success, pid > 0 {
            return pid != ownPID
        }
        // The system-wide element has no pid; it resolves to the focused app.
        return !isOwnAppFocused
    }

    /// True when `pid` is another process that may be queried.
    static func canQuery(pid: pid_t) -> Bool {
        pid > 0 && pid != ownPID
    }

    static var isOwnAppFocused: Bool {
        NSRunningApplication.current.isActive
    }
}
