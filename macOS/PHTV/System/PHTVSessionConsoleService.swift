//
//  PHTVSessionConsoleService.swift
//  PHTV
//
//  Console-session state for multi-user (fast user switching) awareness.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import CoreGraphics
import Foundation

// MARK: - Policy (pure, unit-testable)

enum PHTVUpdateSessionPolicy {
    /// Update activity (checks, downloads, immediate installs) is allowed
    /// unless this login session is explicitly off-console — i.e. another
    /// user account is on the screen. An off-console instance installing
    /// over the bundle the on-console instance is running from is the
    /// system-freeze scenario from issue #196.
    ///
    /// `nil` (session dictionary unavailable) allows updates: it only occurs
    /// in exotic contexts, and permanently blocking updates there would be
    /// worse than the race this guards against.
    static func shouldAllowUpdateActivity(onConsole: Bool?) -> Bool {
        onConsole != false
    }
}

// MARK: - Console session reader

@objcMembers
final class PHTVSessionConsoleService: NSObject {

    /// Whether this login session currently owns the console (screen).
    /// Returns nil when the session dictionary is unavailable.
    class func isSessionOnConsole() -> Bool? {
        guard let sessionInfo = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return nil
        }
        guard let onConsole = sessionInfo[kCGSessionOnConsoleKey as String] as? Bool else {
            return nil
        }
        return onConsole
    }

    /// Convenience wrapper combining the reader with the policy.
    class func shouldAllowUpdateActivity() -> Bool {
        PHTVUpdateSessionPolicy.shouldAllowUpdateActivity(onConsole: isSessionOnConsole())
    }
}
