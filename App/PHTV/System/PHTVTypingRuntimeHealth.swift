//
//  PHTVTypingRuntimeHealth.swift
//  PHTV
//
//  Centralized runtime health snapshot and recovery policy for typing lifecycle.
//

import Foundation

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

    var phase: PHTVTypingRuntimePhase {
        // Accessibility is the ONLY required TCC permission. PHTV creates an active
        // (.defaultTap) session tap, which macOS gates on Accessibility alone — not
        // Input Monitoring (that gate only applies to passive .listenOnly taps).
        // `inputMonitoringTrusted` is retained purely for diagnostics and never
        // blocks the typing phase. The .inputMonitoringRequired case is now legacy
        // and unreachable.
        guard axTrusted else {
            return .accessibilityRequired
        }
        if relaunchPending && !eventTapReady {
            return .relaunchPending
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
        activeBundleId: String? = nil
    ) -> Self {
        Self(
            axTrusted: axTrusted,
            inputMonitoringTrusted: inputMonitoringTrusted,
            eventTapReady: axTrusted && eventTapReady,
            relaunchPending: relaunchPending,
            safeModeEnabled: safeModeEnabled,
            activeAppProfile: activeAppProfile,
            activeBundleId: activeBundleId
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
        activeBundleId: String? = nil
    ) -> PHTVTypingRuntimeHealthSnapshot {
        PHTVTypingRuntimeHealthSnapshot.resolve(
            axTrusted: axTrusted,
            inputMonitoringTrusted: inputMonitoringTrusted,
            eventTapReady: eventTapReady,
            relaunchPending: relaunchPending,
            safeModeEnabled: safeModeEnabled,
            activeAppProfile: activeAppProfile,
            activeBundleId: activeBundleId
        )
    }

    static func shouldRelaunchAfterGrant(
        snapshot: PHTVTypingRuntimeHealthSnapshot,
        needsRelaunchAfterPermission: Bool,
        isEventTapInitialized: Bool
    ) -> Bool {
        snapshot.axTrusted
            && needsRelaunchAfterPermission
            && !isEventTapInitialized
            && !snapshot.isRelaunchPending
    }

    static func shouldFallbackRelaunchAfterEventTapFailures(
        snapshot: PHTVTypingRuntimeHealthSnapshot,
        needsRelaunchAfterPermission: Bool
    ) -> Bool {
        snapshot.axTrusted
            && needsRelaunchAfterPermission
            && !snapshot.isRelaunchPending
    }

    static func shouldPerformInProcessRecovery(
        snapshot: PHTVTypingRuntimeHealthSnapshot
    ) -> Bool {
        !snapshot.isRelaunchPending
    }

    static func shouldScheduleEventTapRecovery(
        snapshot: PHTVTypingRuntimeHealthSnapshot
    ) -> Bool {
        snapshot.axTrusted
            && !snapshot.eventTapReady
            && !snapshot.isRelaunchPending
    }
}
