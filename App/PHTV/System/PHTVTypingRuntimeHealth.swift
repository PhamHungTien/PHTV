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
    case relaunchPending
    case waitingForEventTap
    case ready

    var isReady: Bool {
        self == .ready
    }
}

struct PHTVTypingRuntimeHealthSnapshot: Equatable, Sendable {
    let axTrusted: Bool
    let eventTapReady: Bool
    let relaunchPending: Bool
    let safeModeEnabled: Bool
    let activeAppProfile: PHTVActiveAppProfile
    let activeBundleId: String?

    var phase: PHTVTypingRuntimePhase {
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
        eventTapReady: Bool,
        relaunchPending: Bool,
        safeModeEnabled: Bool,
        activeAppProfile: PHTVActiveAppProfile,
        activeBundleId: String? = nil
    ) -> Self {
        Self(
            axTrusted: axTrusted,
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
        eventTapReady: Bool,
        relaunchPending: Bool,
        safeModeEnabled: Bool,
        activeAppProfile: PHTVActiveAppProfile,
        activeBundleId: String? = nil
    ) -> PHTVTypingRuntimeHealthSnapshot {
        PHTVTypingRuntimeHealthSnapshot.resolve(
            axTrusted: axTrusted,
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
        snapshot: PHTVTypingRuntimeHealthSnapshot
    ) -> Bool {
        snapshot.axTrusted && !snapshot.isRelaunchPending
    }

    static func shouldPerformInProcessRecovery(
        snapshot: PHTVTypingRuntimeHealthSnapshot
    ) -> Bool {
        !snapshot.isRelaunchPending
    }
}
