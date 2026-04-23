//
//  PHTVCompatibilityProfileResolver.swift
//  PHTV
//
//  Data-driven compatibility profile resolution for app-specific typing behavior.
//

import Foundation

private struct PHTVBundlePatternMatcher {
    let exact: Set<String>
    let wildcardPrefixes: [String]

    init(_ patterns: [String]) {
        var exact = Set<String>()
        var wildcardPrefixes: [String] = []

        for pattern in patterns {
            let normalized = pattern.lowercased()
            if normalized.hasSuffix("*") {
                wildcardPrefixes.append(String(normalized.dropLast()))
            } else {
                exact.insert(normalized)
            }
        }

        self.exact = exact
        self.wildcardPrefixes = wildcardPrefixes
    }

    func contains(_ bundleId: String?) -> Bool {
        guard let bundleId = bundleId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !bundleId.isEmpty else {
            return false
        }

        if exact.contains(bundleId) {
            return true
        }

        for prefix in wildcardPrefixes where bundleId.hasPrefix(prefix) {
            return true
        }
        return false
    }
}

struct PHTVCompatibilityProfile: Equatable, Sendable {
    let kind: PHTVActiveAppProfile
    let bundleId: String?
    let isBrowser: Bool
    let isTerminalApp: Bool
    let isIDEApp: Bool
    let isChatApp: Bool
    let isOfficeApp: Bool
    let isSpotlightLike: Bool
    let isTerminalPanel: Bool
    let isCliTarget: Bool
    let needsPrecomposedBatched: Bool
    let needsStepByStep: Bool
    let containsUnicodeCompound: Bool
    let isSafari: Bool
    let needsLegacySpaceCommitFix: Bool
    let needsStrictAddressBarDetection: Bool
    let supportsNativeSystemTextReplacements: Bool
    let cliProfileCode: Int32?
    let shouldPostToHIDTap: Bool
}

final class PHTVCompatibilityProfileResolver: NSObject {
    private static let chatApps = PHTVBundlePatternMatcher([
        "com.tinyspeck.slackmacgap",
        "ru.keepcoder.Telegram",
        "net.whatsapp.WhatsApp",
        "com.hnc.Discord",
        "com.electron.discord",
        "us.zoom.xos",
        "com.microsoft.teams2",
        "com.microsoft.teams",
        "com.facebook.archon",
        "com.vng.zalo"
    ])

    private static let officeApps = PHTVBundlePatternMatcher([
        "com.microsoft.Outlook",
        "com.microsoft.Word",
        "com.microsoft.Excel",
        "com.microsoft.Powerpoint",
        "com.apple.mail",
        "com.apple.iWork.Pages",
        "com.apple.iWork.Numbers",
        "com.apple.iWork.Keynote"
    ])

    private static let systemUIApps = PHTVBundlePatternMatcher([
        "com.apple.systemuiserver",
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
        "com.apple.NotificationCenter",
        "com.apple.controlcenter"
    ])

    class func resolve(
        forBundleId bundleId: String?,
        spotlightActive: Bool,
        isTerminalPanel: Bool,
        isClaudeCodeSession: Bool
    ) -> PHTVCompatibilityProfile {
        let isBrowser = PHTVAppDetectionService.isBrowserApp(bundleId)
        let isTerminalApp = PHTVAppDetectionService.isTerminalApp(bundleId)
        let isIDEApp = PHTVAppDetectionService.isIDEApp(bundleId)
        let isChatApp = chatApps.contains(bundleId)
        let isOfficeApp = officeApps.contains(bundleId)
        let isSpotlightLike = PHTVAppDetectionService.isSpotlightLikeApp(bundleId) || spotlightActive
        let isCliTarget = isTerminalApp || isTerminalPanel || PHTVAppDetectionService.isJetBrainsApp(bundleId)
        let cliProfileCode: Int32? = isCliTarget
            ? PHTVCliProfileService.profileCode(forBundleId: bundleId, isClaudeCodeSession: isClaudeCodeSession)
            : nil

        let kind: PHTVActiveAppProfile = {
            if isSpotlightLike {
                return .spotlightLike
            }
            if isTerminalApp || isTerminalPanel {
                return .terminal
            }
            if isIDEApp {
                return .editorIDE
            }
            if isChatApp {
                return .chat
            }
            if isOfficeApp {
                return .office
            }
            if isBrowser {
                return .browser
            }
            if systemUIApps.contains(bundleId) {
                return .systemUI
            }
            return .generic
        }()

        return PHTVCompatibilityProfile(
            kind: kind,
            bundleId: bundleId,
            isBrowser: isBrowser,
            isTerminalApp: isTerminalApp,
            isIDEApp: isIDEApp,
            isChatApp: isChatApp,
            isOfficeApp: isOfficeApp,
            isSpotlightLike: isSpotlightLike,
            isTerminalPanel: isTerminalPanel,
            isCliTarget: isCliTarget,
            needsPrecomposedBatched: PHTVAppDetectionService.needsPrecomposedBatched(bundleId),
            needsStepByStep: PHTVAppDetectionService.needsStepByStep(bundleId),
            containsUnicodeCompound: PHTVAppDetectionService.containsUnicodeCompound(bundleId),
            isSafari: PHTVAppDetectionService.isSafariApp(bundleId),
            needsLegacySpaceCommitFix: PHTVAppDetectionService.needsLegacySpaceCommitFix(bundleId),
            needsStrictAddressBarDetection: PHTVAppDetectionService.needsStrictAddressBarDetection(bundleId),
            supportsNativeSystemTextReplacements: PHTVAppDetectionService.supportsNativeSystemTextReplacements(bundleId),
            cliProfileCode: cliProfileCode,
            shouldPostToHIDTap: (!isBrowser && spotlightActive) || PHTVAppDetectionService.isSpotlightLikeApp(bundleId)
        )
    }

    class func resolve(forBundleId bundleId: String?) -> PHTVCompatibilityProfile {
        resolve(
            forBundleId: bundleId,
            spotlightActive: false,
            isTerminalPanel: false,
            isClaudeCodeSession: false
        )
    }
}
