//
//  PHTVTextReplacementDecisionService.swift
//  PHTV
//
//  Wraps text-replacement detection decisions for the keydown hot path.
//

import Foundation

@objcMembers
final class PHTVTextReplacementDecisionBox: NSObject {
    let decision: Int32
    let matchedElapsedMs: UInt64
    let shouldBypassEvent: Bool
    let isFallbackNoMatch: Bool

    init(
        decision: Int32,
        matchedElapsedMs: UInt64,
        shouldBypassEvent: Bool,
        isFallbackNoMatch: Bool
    ) {
        self.decision = decision
        self.matchedElapsedMs = matchedElapsedMs
        self.shouldBypassEvent = shouldBypassEvent
        self.isFallbackNoMatch = isFallbackNoMatch
    }
}

@objcMembers
final class PHTVTextReplacementDecisionService: NSObject {
    private static let decisionExternalDelete: Int32 = 1
    private static let decisionPattern2A: Int32 = 2
    private static let decisionPattern2B: Int32 = 3
    private static let decisionFallbackNoMatch: Int32 = 4

    @objc(evaluateForSpaceKey:code:extCode:backspaceCount:newCharCount:externalDeleteCount:restoreAndStartNewSessionCode:willProcessCode:restoreCode:deleteWindowMs:)
    class func evaluate(
        forSpaceKey isSpaceKey: Bool,
        code: Int32,
        extCode: Int32,
        backspaceCount: Int32,
        newCharCount: Int32,
        externalDeleteCount: Int32,
        restoreAndStartNewSessionCode: Int32,
        willProcessCode: Int32,
        restoreCode: Int32,
        deleteWindowMs: UInt64
    ) -> PHTVTextReplacementDecisionBox {
        guard isSpaceKey, backspaceCount > 0 || newCharCount > 0 else {
            return PHTVTextReplacementDecisionBox(
                decision: 0,
                matchedElapsedMs: 0,
                shouldBypassEvent: false,
                isFallbackNoMatch: false
            )
        }

        var matchedElapsedMs: UInt64 = 0
        let decision = Int32(
            PHTVSpotlightDetectionService.detectTextReplacement(
                forCode: Int(code),
                extCode: Int(extCode),
                backspaceCount: Int(backspaceCount),
                newCharCount: Int(newCharCount),
                externalDeleteCount: Int(externalDeleteCount),
                restoreAndStartNewSessionCode: Int(restoreAndStartNewSessionCode),
                willProcessCode: Int(willProcessCode),
                restoreCode: Int(restoreCode),
                deleteWindowMs: deleteWindowMs,
                matchedElapsedMs: &matchedElapsedMs
            )
        )

        let shouldBypassEvent =
            decision == decisionExternalDelete ||
            decision == decisionPattern2A ||
            decision == decisionPattern2B

        return PHTVTextReplacementDecisionBox(
            decision: decision,
            matchedElapsedMs: matchedElapsedMs,
            shouldBypassEvent: shouldBypassEvent,
            isFallbackNoMatch: decision == decisionFallbackNoMatch
        )
    }
}
