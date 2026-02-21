//
//  PHTVInputStrategyService.swift
//  PHTV
//
//  Centralized boolean decision matrix for browser/non-browser input fixes.
//

import Foundation

@objc
enum PHTVBackspaceAdjustmentAction: Int32 {
    case none = 0
    case sendEmptyCharacter = 1
    case sendShiftLeftThenBackspace = 2
}

@objcMembers
final class PHTVBackspaceAdjustmentBox: NSObject {
    let action: Int32
    let adjustedBackspaceCount: Int32

    init(
        action: Int32,
        adjustedBackspaceCount: Int32
    ) {
        self.action = action
        self.adjustedBackspaceCount = adjustedBackspaceCount
    }
}

@objcMembers
final class PHTVCharacterSendPlanBox: NSObject {
    let deferBackspaceToAX: Bool
    let useStepByStepBackspace: Bool
    let useStepByStepCharacterSend: Bool
    let shouldSendRestoreTriggerKey: Bool
    let shouldStartNewSessionAfterSend: Bool

    init(
        deferBackspaceToAX: Bool,
        useStepByStepBackspace: Bool,
        useStepByStepCharacterSend: Bool,
        shouldSendRestoreTriggerKey: Bool,
        shouldStartNewSessionAfterSend: Bool
    ) {
        self.deferBackspaceToAX = deferBackspaceToAX
        self.useStepByStepBackspace = useStepByStepBackspace
        self.useStepByStepCharacterSend = useStepByStepCharacterSend
        self.shouldSendRestoreTriggerKey = shouldSendRestoreTriggerKey
        self.shouldStartNewSessionAfterSend = shouldStartNewSessionAfterSend
    }
}

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

    @objc(backspaceAdjustmentForBrowserAddressBarFix:addressBarDetected:legacyNonBrowserFix:containsUnicodeCompound:notionCodeBlockDetected:backspaceCount:)
    class func backspaceAdjustment(
        forBrowserAddressBarFix shouldTryBrowserAddressBarFix: Bool,
        addressBarDetected isAddressBarDetected: Bool,
        legacyNonBrowserFix shouldTryLegacyNonBrowserFix: Bool,
        containsUnicodeCompound: Bool,
        notionCodeBlockDetected isNotionCodeBlockDetected: Bool,
        backspaceCount: Int32
    ) -> PHTVBackspaceAdjustmentBox {
        guard backspaceCount > 0 else {
            return PHTVBackspaceAdjustmentBox(
                action: PHTVBackspaceAdjustmentAction.none.rawValue,
                adjustedBackspaceCount: max(0, backspaceCount)
            )
        }

        if shouldTryBrowserAddressBarFix && isAddressBarDetected {
            return PHTVBackspaceAdjustmentBox(
                action: PHTVBackspaceAdjustmentAction.sendEmptyCharacter.rawValue,
                adjustedBackspaceCount: backspaceCount + 1
            )
        }

        if shouldTryLegacyNonBrowserFix && !isNotionCodeBlockDetected {
            if containsUnicodeCompound {
                return PHTVBackspaceAdjustmentBox(
                    action: PHTVBackspaceAdjustmentAction.sendShiftLeftThenBackspace.rawValue,
                    adjustedBackspaceCount: backspaceCount - 1
                )
            }
            return PHTVBackspaceAdjustmentBox(
                action: PHTVBackspaceAdjustmentAction.sendEmptyCharacter.rawValue,
                adjustedBackspaceCount: backspaceCount + 1
            )
        }

        return PHTVBackspaceAdjustmentBox(
            action: PHTVBackspaceAdjustmentAction.none.rawValue,
            adjustedBackspaceCount: backspaceCount
        )
    }

    @objc(characterSendPlanForSpotlightTarget:cliTarget:globalStepByStep:appNeedsStepByStep:keyCode:engineCode:restoreCode:restoreAndStartNewSessionCode:enterKeyCode:returnKeyCode:)
    class func characterSendPlan(
        forSpotlightTarget isSpotlightTarget: Bool,
        cliTarget isCliTarget: Bool,
        globalStepByStep globalStepByStepEnabled: Bool,
        appNeedsStepByStep appNeedsStepByStepEnabled: Bool,
        keyCode: Int32,
        engineCode: Int32,
        restoreCode: Int32,
        restoreAndStartNewSessionCode: Int32,
        enterKeyCode: Int32,
        returnKeyCode: Int32
    ) -> PHTVCharacterSendPlanBox {
        let isAutoEnglishWithEnter =
            engineCode == restoreAndStartNewSessionCode &&
            (keyCode == enterKeyCode || keyCode == returnKeyCode)

        let useStepByStepCharacterSend =
            !isSpotlightTarget &&
            (isCliTarget ||
             globalStepByStepEnabled ||
             appNeedsStepByStepEnabled ||
             isAutoEnglishWithEnter)

        let shouldSendRestoreTriggerKey =
            useStepByStepCharacterSend &&
            (engineCode == restoreCode || engineCode == restoreAndStartNewSessionCode)

        return PHTVCharacterSendPlanBox(
            deferBackspaceToAX: isSpotlightTarget,
            useStepByStepBackspace: !isSpotlightTarget && appNeedsStepByStepEnabled,
            useStepByStepCharacterSend: useStepByStepCharacterSend,
            shouldSendRestoreTriggerKey: shouldSendRestoreTriggerKey,
            shouldStartNewSessionAfterSend: useStepByStepCharacterSend && engineCode == restoreAndStartNewSessionCode
        )
    }

    @objc(shouldTemporarilyUseUnicodeCodeTableForCurrentCodeTable:spotlightActive:spotlightLikeApp:)
    class func shouldTemporarilyUseUnicodeCodeTable(
        forCurrentCodeTable currentCodeTable: Int32,
        spotlightActive: Bool,
        spotlightLikeApp: Bool
    ) -> Bool {
        return currentCodeTable == 3 && (spotlightActive || spotlightLikeApp)
    }
}
