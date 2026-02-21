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

@objc
enum PHTVSyncKeyAction: Int32 {
    case none = 0
    case clear = 1
    case pop = 2
    case popAndSendBackspace = 3
    case insertOne = 4
}

@objc
enum PHTVEngineSignalAction: Int32 {
    case none = 0
    case doNothing = 1
    case processSignal = 2
    case replaceMacro = 3
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
    let useStepByStepCharacterSend: Bool
    let shouldSendRestoreTriggerKey: Bool
    let shouldStartNewSessionAfterSend: Bool

    init(
        deferBackspaceToAX: Bool,
        useStepByStepCharacterSend: Bool,
        shouldSendRestoreTriggerKey: Bool,
        shouldStartNewSessionAfterSend: Bool
    ) {
        self.deferBackspaceToAX = deferBackspaceToAX
        self.useStepByStepCharacterSend = useStepByStepCharacterSend
        self.shouldSendRestoreTriggerKey = shouldSendRestoreTriggerKey
        self.shouldStartNewSessionAfterSend = shouldStartNewSessionAfterSend
    }
}

@objcMembers
final class PHTVMacroPlanBox: NSObject {
    let isSpotlightLikeTarget: Bool
    let shouldTryAXReplacement: Bool
    let shouldApplyBrowserFix: Bool
    let adjustedBackspaceCount: Int32
    let useStepByStepSend: Bool
    let shouldSendTriggerKey: Bool

    init(
        isSpotlightLikeTarget: Bool,
        shouldTryAXReplacement: Bool,
        shouldApplyBrowserFix: Bool,
        adjustedBackspaceCount: Int32,
        useStepByStepSend: Bool,
        shouldSendTriggerKey: Bool
    ) {
        self.isSpotlightLikeTarget = isSpotlightLikeTarget
        self.shouldTryAXReplacement = shouldTryAXReplacement
        self.shouldApplyBrowserFix = shouldApplyBrowserFix
        self.adjustedBackspaceCount = adjustedBackspaceCount
        self.useStepByStepSend = useStepByStepSend
        self.shouldSendTriggerKey = shouldSendTriggerKey
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
            backspaceCount > 0 &&
            !isSpecialApp &&
            !shouldSkipSpace &&
            !isPotentialShortcut

        let shouldTryLegacyNonBrowserFix =
            browserFixEnabled &&
            extCode != 4 &&
            backspaceCount > 0 &&
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
            useStepByStepCharacterSend: useStepByStepCharacterSend,
            shouldSendRestoreTriggerKey: shouldSendRestoreTriggerKey,
            shouldStartNewSessionAfterSend: useStepByStepCharacterSend && engineCode == restoreAndStartNewSessionCode
        )
    }

    @objc(sanitizedBackspaceCountForAdjustedCount:maxBuffer:safetyLimit:)
    class func sanitizedBackspaceCount(
        forAdjustedCount adjustedCount: Int32,
        maxBuffer: Int32,
        safetyLimit: Int32
    ) -> Int32 {
        var count = max(0, adjustedCount)
        count = min(count, maxBuffer)
        count = min(count, safetyLimit)
        return count
    }

    @objc(shouldTemporarilyUseUnicodeCodeTableForCurrentCodeTable:spotlightActive:spotlightLikeApp:)
    class func shouldTemporarilyUseUnicodeCodeTable(
        forCurrentCodeTable currentCodeTable: Int32,
        spotlightActive: Bool,
        spotlightLikeApp: Bool
    ) -> Bool {
        return currentCodeTable == 3 && (spotlightActive || spotlightLikeApp)
    }

    @objc(macroPlanForPostToHIDTap:appIsSpotlightLike:browserFixEnabled:originalBackspaceCount:cliTarget:globalStepByStep:appNeedsStepByStep:)
    class func macroPlan(
        forPostToHIDTap postToHIDTap: Bool,
        appIsSpotlightLike: Bool,
        browserFixEnabled: Bool,
        originalBackspaceCount: Int32,
        cliTarget: Bool,
        globalStepByStep: Bool,
        appNeedsStepByStep: Bool
    ) -> PHTVMacroPlanBox {
        let isSpotlightLikeTarget = postToHIDTap || appIsSpotlightLike
        let shouldApplyBrowserFix = browserFixEnabled
        let adjustedBackspaceCount = originalBackspaceCount + (shouldApplyBrowserFix ? 1 : 0)
        let useStepByStepSend = cliTarget || globalStepByStep || appNeedsStepByStep

        return PHTVMacroPlanBox(
            isSpotlightLikeTarget: isSpotlightLikeTarget,
            shouldTryAXReplacement: isSpotlightLikeTarget,
            shouldApplyBrowserFix: shouldApplyBrowserFix,
            adjustedBackspaceCount: adjustedBackspaceCount,
            useStepByStepSend: useStepByStepSend,
            shouldSendTriggerKey: !isSpotlightLikeTarget
        )
    }

    @objc(syncKeyActionForCodeTable:extCode:hasSyncKey:syncKeyBackValue:containsUnicodeCompound:)
    class func syncKeyAction(
        forCodeTable codeTable: Int32,
        extCode: Int32,
        hasSyncKey: Bool,
        syncKeyBackValue: Int32,
        containsUnicodeCompound: Bool
    ) -> Int32 {
        let isDoubleCode = (codeTable == 2 || codeTable == 3)
        guard isDoubleCode else {
            return PHTVSyncKeyAction.none.rawValue
        }

        switch extCode {
        case 1:
            return PHTVSyncKeyAction.clear.rawValue
        case 2:
            guard hasSyncKey else {
                return PHTVSyncKeyAction.none.rawValue
            }
            if syncKeyBackValue > 1 && (codeTable == 2 || !containsUnicodeCompound) {
                return PHTVSyncKeyAction.popAndSendBackspace.rawValue
            }
            return PHTVSyncKeyAction.pop.rawValue
        case 3:
            return PHTVSyncKeyAction.insertOne.rawValue
        default:
            return PHTVSyncKeyAction.none.rawValue
        }
    }

    @objc(shouldBypassSpaceForFigmaWithBundleId:keyCode:backspaceCount:newCharCount:spaceKeyCode:)
    class func shouldBypassSpaceForFigma(
        withBundleId bundleId: String?,
        keyCode: Int32,
        backspaceCount: Int32,
        newCharCount: Int32,
        spaceKeyCode: Int32
    ) -> Bool {
        guard keyCode == spaceKeyCode else {
            return false
        }
        guard backspaceCount == 0, newCharCount == 1 else {
            return false
        }
        return bundleId == "com.figma.Desktop"
    }

    @objc(engineSignalActionForEngineCode:doNothingCode:willProcessCode:restoreCode:restoreAndStartNewSessionCode:replaceMacroCode:)
    class func engineSignalAction(
        forEngineCode code: Int32,
        doNothingCode: Int32,
        willProcessCode: Int32,
        restoreCode: Int32,
        restoreAndStartNewSessionCode: Int32,
        replaceMacroCode: Int32
    ) -> Int32 {
        if code == willProcessCode || code == restoreCode || code == restoreAndStartNewSessionCode {
            return PHTVEngineSignalAction.processSignal.rawValue
        }
        if code == replaceMacroCode {
            return PHTVEngineSignalAction.replaceMacro.rawValue
        }
        if code == doNothingCode {
            return PHTVEngineSignalAction.doNothing.rawValue
        }
        return PHTVEngineSignalAction.none.rawValue
    }
}
