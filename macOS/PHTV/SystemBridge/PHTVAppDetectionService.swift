//
//  PHTVAppDetectionService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

private struct BundlePatternSet {
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
        guard let normalizedBundleId = Self.normalizeBundleId(bundleId) else {
            return false
        }
        if exact.contains(normalizedBundleId) {
            return true
        }
        for prefix in wildcardPrefixes where normalizedBundleId.hasPrefix(prefix) {
            return true
        }
        return false
    }

    private static func normalizeBundleId(_ bundleId: String?) -> String? {
        guard let bundleId = bundleId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleId.isEmpty else {
            return nil
        }
        return bundleId.lowercased()
    }
}

// Swift source of truth for app detection rules.
// ObjC/ObjC++ code can call this service directly via PHTV-Swift.h.
@objcMembers
final class PHTVAppDetectionService: NSObject {
    private static let niceSpaceApps = BundlePatternSet([
        "com.sublimetext.3",
        "com.sublimetext.2"
    ])

    private static let safariApps = BundlePatternSet([
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.apple.Safari.WebApp.*"
    ])

    private static let unicodeCompoundApps = BundlePatternSet([
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.apple.Safari.WebApp.*",
        "com.google.Chrome",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Dev",
        "com.microsoft.edgemac.Beta",
        "com.microsoft.Edge",
        "com.microsoft.Edge.Dev",
        "com.thebrowser.Browser",
        "company.thebrowser.dia",
        "org.chromium.Chromium",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "notion.id",
        "com.google.Chrome.app.*",
        "com.brave.Browser.app.*",
        "com.microsoft.edgemac.app.*",
        "com.microsoft.edgemac.Dev.app.*",
        "com.microsoft.edgemac.Beta.app.*",
        "com.microsoft.Edge.app.*",
        "com.microsoft.Edge.Dev.app.*",
        "com.thebrowser.Browser.app.*",
        "org.chromium.Chromium.app.*",
        "com.vivaldi.Vivaldi.app.*",
        "com.operasoftware.Opera.app.*"
    ])

    private static let browserApps = BundlePatternSet([
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.apple.Safari.WebApp.*",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "app.zen-browser.zen",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.dev",
        "com.google.Chrome.beta",
        "org.chromium.Chromium",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Dev",
        "com.microsoft.edgemac.Beta",
        "com.microsoft.edgemac.Canary",
        "com.microsoft.Edge",
        "com.microsoft.Edge.Dev",
        "com.thebrowser.Browser",
        "ai.perplexity.comet",
        "com.visualkit.browser",
        "com.coccoc.browser",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "com.operasoftware.OperaGX",
        "com.kagi.kagimacOS",
        "com.duckduckgo.macos.browser",
        "com.sigmaos.sigmaos.macos",
        "com.pushplaylabs.sidekick",
        "com.bookry.wavebox",
        "com.mighty.app",
        "com.collovos.naver.whale",
        "ru.yandex.desktop.yandex-browser",
        "com.google.Chrome.app.*",
        "com.google.Chrome.canary.app.*",
        "com.google.Chrome.dev.app.*",
        "com.google.Chrome.beta.app.*",
        "org.chromium.Chromium.app.*",
        "com.brave.Browser.app.*",
        "com.brave.Browser.beta.app.*",
        "com.brave.Browser.nightly.app.*",
        "com.microsoft.edgemac.app.*",
        "com.microsoft.edgemac.Dev.app.*",
        "com.microsoft.edgemac.Beta.app.*",
        "com.microsoft.edgemac.Canary.app.*",
        "com.microsoft.Edge.app.*",
        "com.microsoft.Edge.Dev.app.*",
        "com.thebrowser.Browser.app.*",
        "com.vivaldi.Vivaldi.app.*",
        "com.operasoftware.Opera.app.*",
        "com.operasoftware.OperaGX.app.*",
        "com.coccoc.browser.app.*",
        "com.kagi.kagimacOS.app.*",
        "com.sigmaos.sigmaos.macos.app.*",
        "com.pushplaylabs.sidekick.app.*",
        "com.bookry.wavebox.app.*",
        "com.collovos.naver.whale.app.*",
        "ru.yandex.desktop.yandex-browser.app.*",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "com.electron.discord",
        "com.github.GitHubClient",
        "com.figma.Desktop",
        "com.linear",
        "com.logseq.logseq",
        "md.obsidian"
    ])

    private static let terminalApps = BundlePatternSet([
        "com.apple.Terminal",
        "io.alacritty",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "com.raphaelamorim.rio",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "co.zeit.hyper",
        "org.tabby",
        "com.termius-dmg.mac"
    ])

    private static let fastTerminalApps = BundlePatternSet([
        "io.alacritty",
        "com.mitchellh.ghostty",
        "com.raphaelamorim.rio"
    ])

    private static let mediumTerminalApps = BundlePatternSet([
        "com.apple.Terminal",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "co.zeit.hyper",
        "org.tabby",
        "com.termius-dmg.mac"
    ])

    private static let slowTerminalApps = BundlePatternSet([])

    private static let vscodeFamilyApps: Set<String> = [
        "com.microsoft.vscode",
        "com.microsoft.vscodeinsiders",
        "com.visualstudio.code.oss",
        "com.vscodium",
        "com.vscodium.codium",
        "com.google.antigravity",
        "com.todesktop.cursor",
        "com.todesktop.230313mzl4w4u92"
    ]

    private static let forcePrecomposedApps = BundlePatternSet([
        "com.apple.Spotlight",
        "com.apple.systemuiserver",
        "com.raycast.*"
    ])

    private static let precomposedBatchedApps = BundlePatternSet([
        "net.whatsapp.WhatsApp",
        "notion.id"
    ])

    private static let stepByStepApps = BundlePatternSet([
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
        "com.alfredapp.Alfred",
        "com.apple.launchpad",
        "notion.id",
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.apple.Safari.WebApp.*"
    ])

    private static let disableVietnameseApps = BundlePatternSet([
        "com.apple.apps.launcher",
        "com.apple.ScreenContinuity"
    ])

    private static let terminalKeywords: [String] = [
        "terminal",
        "xterm",
        "shell",
        "console",
        "vscode-terminal",
        "terminal.integrated",
        "xterm.js",
        "terminalview",
        "terminalpanel",
        "toolwindow terminal",
        "tool window: terminal",
        "terminal tool window",
        "command line",
        "pty",
        "tty"
    ]

    private static func normalizeBundleId(_ bundleId: String?) -> String? {
        guard let bundleId = bundleId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleId.isEmpty else {
            return nil
        }
        return bundleId.lowercased()
    }

    @objc class func isBrowserApp(_ bundleId: String?) -> Bool {
        browserApps.contains(bundleId)
    }

    @objc class func isSpotlightLikeApp(_ bundleId: String?) -> Bool {
        forcePrecomposedApps.contains(bundleId)
    }

    @objc class func needsPrecomposedBatched(_ bundleId: String?) -> Bool {
        precomposedBatchedApps.contains(bundleId)
    }

    @objc class func needsStepByStep(_ bundleId: String?) -> Bool {
        stepByStepApps.contains(bundleId)
    }

    @objc class func containsUnicodeCompound(_ bundleId: String?) -> Bool {
        unicodeCompoundApps.contains(bundleId)
    }

    @objc class func isSafariApp(_ bundleId: String?) -> Bool {
        safariApps.contains(bundleId)
    }

    @objc class func shouldDisableVietnamese(_ bundleId: String?) -> Bool {
        disableVietnameseApps.contains(bundleId)
    }

    @objc class func needsNiceSpace(_ bundleId: String?) -> Bool {
        niceSpaceApps.contains(bundleId)
    }

    @objc class func isTerminalApp(_ bundleId: String?) -> Bool {
        terminalApps.contains(bundleId)
    }

    @objc class func isFastTerminalApp(_ bundleId: String?) -> Bool {
        fastTerminalApps.contains(bundleId)
    }

    @objc class func isMediumTerminalApp(_ bundleId: String?) -> Bool {
        mediumTerminalApps.contains(bundleId)
    }

    @objc class func isSlowTerminalApp(_ bundleId: String?) -> Bool {
        slowTerminalApps.contains(bundleId)
    }

    @objc class func isVSCodeFamilyApp(_ bundleId: String?) -> Bool {
        guard let normalized = normalizeBundleId(bundleId) else {
            return false
        }
        return vscodeFamilyApps.contains(normalized)
    }

    @objc class func isJetBrainsApp(_ bundleId: String?) -> Bool {
        guard let normalized = normalizeBundleId(bundleId) else {
            return false
        }
        return normalized.hasPrefix("com.jetbrains.") || normalized == "com.google.android.studio"
    }

    @objc class func isIDEApp(_ bundleId: String?) -> Bool {
        isVSCodeFamilyApp(bundleId) || isJetBrainsApp(bundleId)
    }

    @objc class func containsTerminalKeyword(_ value: String?) -> Bool {
        guard let normalized = value?.lowercased(), !normalized.isEmpty else {
            return false
        }
        for keyword in terminalKeywords where normalized.contains(keyword) {
            return true
        }
        return false
    }

    @objc(bundleIdMatchesAppSet:appSet:)
    class func bundleIdMatchesAppSet(_ bundleId: String?, appSet: NSSet?) -> Bool {
        guard let bundleId,
              let appSet = appSet as? Set<AnyHashable> else {
            return false
        }

        let normalizedBundleId = bundleId.lowercased()

        if appSet.contains(bundleId as AnyHashable) || appSet.contains(normalizedBundleId as AnyHashable) {
            return true
        }

        for patternAny in appSet {
            guard let pattern = patternAny as? String else {
                continue
            }
            let normalizedPattern = pattern.lowercased()
            if normalizedPattern.hasSuffix("*") {
                let prefix = String(normalizedPattern.dropLast())
                if normalizedBundleId.hasPrefix(prefix) {
                    return true
                }
            }
        }

        return false
    }
}
