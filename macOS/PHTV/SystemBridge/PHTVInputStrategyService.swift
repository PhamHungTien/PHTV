//
//  PHTVInputStrategyService.swift
//  PHTV
//
//  Centralized boolean decision matrix for browser/non-browser input fixes.
//

import Foundation

@objcMembers
final class PHTVInputStrategyBox: NSObject {
    let isSpecialApp: Bool
    let isPotentialShortcut: Bool
    let isBrowserFix: Bool
    let shouldSkipSpace: Bool
    let shouldTryBrowserAddressBarFix: Bool
    let shouldTryLegacyNonBrowserFix: Bool
    let shouldLogSpaceSkip: Bool

    init(
        isSpecialApp: Bool,
        isPotentialShortcut: Bool,
        isBrowserFix: Bool,
        shouldSkipSpace: Bool,
        shouldTryBrowserAddressBarFix: Bool,
        shouldTryLegacyNonBrowserFix: Bool,
        shouldLogSpaceSkip: Bool
    ) {
        self.isSpecialApp = isSpecialApp
        self.isPotentialShortcut = isPotentialShortcut
        self.isBrowserFix = isBrowserFix
        self.shouldSkipSpace = shouldSkipSpace
        self.shouldTryBrowserAddressBarFix = shouldTryBrowserAddressBarFix
        self.shouldTryLegacyNonBrowserFix = shouldTryLegacyNonBrowserFix
        self.shouldLogSpaceSkip = shouldLogSpaceSkip
    }
}

@objcMembers
final class PHTVInputStrategyService: NSObject {
    @objc(strategyForSpaceKey:slashKey:extCode:backspaceCount:isBrowserApp:isSpotlightTarget:needsPrecomposedBatched:browserFixEnabled:isNotionApp:)
    class func strategy(
        forSpaceKey isSpaceKey: Bool,
        slashKey isSlashKey: Bool,
        extCode: Int32,
        backspaceCount: Int32,
        isBrowserApp: Bool,
        isSpotlightTarget: Bool,
        needsPrecomposedBatched: Bool,
        browserFixEnabled: Bool,
        isNotionApp: Bool
    ) -> PHTVInputStrategyBox {
        let isSpecialApp = isSpotlightTarget || needsPrecomposedBatched
        let isPotentialShortcut = isSlashKey
        let isBrowserFix = browserFixEnabled && isBrowserApp

        let isSpaceRestore = isSpaceKey && backspaceCount > 0
        let shouldSkipSpace = isSpaceKey && !isSpaceRestore

        let shouldTryBrowserAddressBarFix =
            isBrowserFix &&
            extCode != 4 &&
            !isSpecialApp &&
            !shouldSkipSpace &&
            !isPotentialShortcut

        let shouldTryLegacyNonBrowserFix =
            browserFixEnabled &&
            extCode != 4 &&
            (!isSpecialApp || isNotionApp) &&
            !isSpaceKey &&
            !isPotentialShortcut &&
            !isBrowserApp

        let shouldLogSpaceSkip =
            isSpaceKey &&
            browserFixEnabled &&
            extCode != 4 &&
            !isSpecialApp

        return PHTVInputStrategyBox(
            isSpecialApp: isSpecialApp,
            isPotentialShortcut: isPotentialShortcut,
            isBrowserFix: isBrowserFix,
            shouldSkipSpace: shouldSkipSpace,
            shouldTryBrowserAddressBarFix: shouldTryBrowserAddressBarFix,
            shouldTryLegacyNonBrowserFix: shouldTryLegacyNonBrowserFix,
            shouldLogSpaceSkip: shouldLogSpaceSkip
        )
    }
}
