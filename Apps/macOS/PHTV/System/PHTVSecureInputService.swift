//
//  PHTVSecureInputService.swift
//  PHTV
//
//  Reports which process holds macOS Secure Event Input.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Carbon
import Foundation

/// While any process keeps Secure Event Input on, macOS withholds keystrokes
/// from every event tap, so no input method can add accents. Password fields
/// turn it on briefly; some apps leave it on (a Terminal with Secure Keyboard
/// Entry, a stuck password prompt). PHTV cannot override this, but it can name
/// the app responsible so the user knows what to close.
enum PHTVSecureInputService {
    struct Status: Equatable {
        let isEnabled: Bool
        let ownerPID: pid_t?
        let ownerName: String?

        static let disabled = Status(isEnabled: false, ownerPID: nil, ownerName: nil)

        var reportDescription: String {
            guard isEnabled else { return "Off" }
            let owner = ownerName ?? "Unknown"
            if let ownerPID {
                return "⚠️ On — \(owner) (pid \(ownerPID))"
            }
            return "⚠️ On — \(owner)"
        }

        var menuDescription: String? {
            guard isEnabled else { return nil }
            if let ownerName {
                return "\(ownerName) đang bật Nhập liệu bảo mật"
            }
            return "macOS đang bật Nhập liệu bảo mật"
        }
    }

    static func ownerPID(fromSessionDictionary dictionary: [String: Any]?) -> pid_t? {
        guard let value = dictionary?["kCGSSessionSecureInputPID"] as? NSNumber else {
            return nil
        }
        let pid = value.int32Value
        return pid > 0 ? pid : nil
    }

    static func currentStatus() -> Status {
        guard IsSecureEventInputEnabled() else {
            return .disabled
        }
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        let pid = ownerPID(fromSessionDictionary: session)
        let name = pid.flatMap { NSRunningApplication(processIdentifier: $0)?.localizedName }
            ?? pid.flatMap(processName(forPID:))
        return Status(isEnabled: true, ownerPID: pid, ownerName: name)
    }

    private static func processName(forPID pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        let bytes = buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// True when the console session belongs to this user and is active.
    /// Fast user switching moves keystrokes to another session.
    static func isSessionOnConsole() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return true
        }
        if let onConsole = session[kCGSessionOnConsoleKey as String] as? Bool {
            return onConsole
        }
        return true
    }
}
