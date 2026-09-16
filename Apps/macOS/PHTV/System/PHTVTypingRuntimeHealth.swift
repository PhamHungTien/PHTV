//
//  PHTVTypingRuntimeHealth.swift
//  PHTV
//
//  Centralized runtime health snapshot and recovery policy for typing lifecycle.
//

import Foundation
import Carbon

enum PHTVSecureInputStatus {
    // Carbon documents this query as not thread-safe. Sample it from the
    // main-actor health monitor, never from the keyboard callback.
    @MainActor static var isEnabled: Bool { IsSecureEventInputEnabled() }

    static let guidance = "macOS đang bật nhập liệu bảo mật nên PHTV tạm thời không nhận được phím. Hãy rời ô mật khẩu; nếu vẫn bị chặn, đóng tab hoặc ứng dụng vừa dùng ô mật khẩu. PHTV sẽ tự tiếp tục khi chế độ này kết thúc."
}

enum PHTVActiveAppProfile: String, CaseIterable, Equatable, Sendable {
    case generic
    case browser
    case editorIDE
    case chat
    case office
    case terminal
    case spotlightLike
    case systemUI

    var displayName: String {
        switch self {
        case .generic:
            return "Ứng dụng thường"
        case .browser:
            return "Trình duyệt"
        case .editorIDE:
            return "Editor / IDE"
        case .chat:
            return "Chat"
        case .office:
            return "Văn phòng"
        case .terminal:
            return "Terminal / CLI"
        case .spotlightLike:
            return "Spotlight-like"
        case .systemUI:
            return "Hệ thống"
        }
    }
}

enum PHTVTypingRuntimePhase: String, Equatable, Sendable {
    case accessibilityRequired
    case inputMonitoringRequired
    case relaunchPending
    case waitingForEventTap
    case secureInputActive
    case ready

    var isReady: Bool {
        self == .ready
    }
}

struct PHTVTypingRuntimeHealthSnapshot: Equatable, Sendable {
    let axTrusted: Bool
    let inputMonitoringTrusted: Bool
    let eventTapReady: Bool
    let relaunchPending: Bool
    let safeModeEnabled: Bool
    let activeAppProfile: PHTVActiveAppProfile
    let activeBundleId: String?
    let secureInputEnabled: Bool

    var phase: PHTVTypingRuntimePhase {
        guard axTrusted else {
            return .accessibilityRequired
        }
        guard inputMonitoringTrusted else {
            return .inputMonitoringRequired
        }
        if relaunchPending && !eventTapReady {
            return .relaunchPending
        }
        if secureInputEnabled {
            return .secureInputActive
        }
        return eventTapReady ? .ready : .waitingForEventTap
    }

    var hasAccessibilityPermission: Bool {
        axTrusted
    }

    var hasInputMonitoringPermission: Bool {
        inputMonitoringTrusted
    }

    var isTypingPermissionReady: Bool {
        phase.isReady
    }

    var permissionState: PHTVTypingPermissionState {
        PHTVTypingPermissionState.resolve(snapshot: self)
    }

    var guidanceStep: PHTVPermissionGuidanceStep {
        PHTVPermissionGuidanceStep.resolve(snapshot: self)
    }

    var isRelaunchPending: Bool {
        phase == .relaunchPending
    }

    static func resolve(
        axTrusted: Bool,
        inputMonitoringTrusted: Bool = true,
        eventTapReady: Bool,
        relaunchPending: Bool,
        safeModeEnabled: Bool,
        activeAppProfile: PHTVActiveAppProfile,
        activeBundleId: String? = nil,
        secureInputEnabled: Bool = false
    ) -> Self {
        Self(
            axTrusted: axTrusted,
            inputMonitoringTrusted: inputMonitoringTrusted,
            eventTapReady: axTrusted && inputMonitoringTrusted && eventTapReady,
            relaunchPending: relaunchPending,
            safeModeEnabled: safeModeEnabled,
            activeAppProfile: activeAppProfile,
            activeBundleId: activeBundleId,
            secureInputEnabled: secureInputEnabled
        )
    }
}

enum PHTVTypingRuntimeStateMachine {
    static func snapshot(
        axTrusted: Bool,
        inputMonitoringTrusted: Bool = true,
        eventTapReady: Bool,
        relaunchPending: Bool,
        safeModeEnabled: Bool,
        activeAppProfile: PHTVActiveAppProfile,
        activeBundleId: String? = nil,
        secureInputEnabled: Bool = false
    ) -> PHTVTypingRuntimeHealthSnapshot {
        PHTVTypingRuntimeHealthSnapshot.resolve(
            axTrusted: axTrusted,
            inputMonitoringTrusted: inputMonitoringTrusted,
            eventTapReady: eventTapReady,
            relaunchPending: relaunchPending,
            safeModeEnabled: safeModeEnabled,
            activeAppProfile: activeAppProfile,
            activeBundleId: activeBundleId,
            secureInputEnabled: secureInputEnabled
        )
    }

    static func shouldRelaunchAfterGrant(
        snapshot: PHTVTypingRuntimeHealthSnapshot,
        needsRelaunchAfterPermission: Bool,
        isEventTapInitialized: Bool
    ) -> Bool {
        snapshot.axTrusted
            && snapshot.inputMonitoringTrusted
            && !snapshot.secureInputEnabled
            && needsRelaunchAfterPermission
            && !isEventTapInitialized
            && !snapshot.isRelaunchPending
    }

    static func shouldFallbackRelaunchAfterEventTapFailures(
        snapshot: PHTVTypingRuntimeHealthSnapshot,
        needsRelaunchAfterPermission: Bool
    ) -> Bool {
        snapshot.axTrusted
            && snapshot.inputMonitoringTrusted
            && !snapshot.secureInputEnabled
            && needsRelaunchAfterPermission
            && !snapshot.isRelaunchPending
    }

    static func shouldPerformInProcessRecovery(
        snapshot: PHTVTypingRuntimeHealthSnapshot
    ) -> Bool {
        !snapshot.isRelaunchPending && !snapshot.secureInputEnabled
    }

    static func shouldScheduleEventTapRecovery(
        snapshot: PHTVTypingRuntimeHealthSnapshot
    ) -> Bool {
        snapshot.axTrusted
            && snapshot.inputMonitoringTrusted
            && !snapshot.secureInputEnabled
            && !snapshot.eventTapReady
            && !snapshot.isRelaunchPending
    }
}
