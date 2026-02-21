//
//  PHTVSendSequenceService.swift
//  PHTV
//
//  Shared execution-plan helpers for step-by-step synthetic text sending.
//

import Foundation

@objcMembers
final class PHTVSendSequencePlanBox: NSObject {
    let interItemDelayUs: Int64
    let shouldScheduleCliBlock: Bool
    let cliBlockUs: Int64

    init(
        interItemDelayUs: Int64,
        shouldScheduleCliBlock: Bool,
        cliBlockUs: Int64
    ) {
        self.interItemDelayUs = interItemDelayUs
        self.shouldScheduleCliBlock = shouldScheduleCliBlock
        self.cliBlockUs = cliBlockUs
    }
}

@objcMembers
final class PHTVSendSequenceService: NSObject {
    @objc(sequencePlanForCliTarget:itemCount:scaledCliTextDelayUs:scaledCliPostSendBlockUs:)
    class func sequencePlan(
        forCliTarget isCliTarget: Bool,
        itemCount: Int32,
        scaledCliTextDelayUs: Int64,
        scaledCliPostSendBlockUs: Int64
    ) -> PHTVSendSequencePlanBox {
        guard isCliTarget, itemCount > 0 else {
            return PHTVSendSequencePlanBox(
                interItemDelayUs: 0,
                shouldScheduleCliBlock: false,
                cliBlockUs: 0
            )
        }

        let interItemDelayUs = max(0, scaledCliTextDelayUs)
        var totalBlockUs = max(0, scaledCliPostSendBlockUs)
        if interItemDelayUs > 0 && itemCount > 1 {
            totalBlockUs += interItemDelayUs * Int64(itemCount - 1)
        }

        return PHTVSendSequencePlanBox(
            interItemDelayUs: interItemDelayUs,
            shouldScheduleCliBlock: true,
            cliBlockUs: totalBlockUs
        )
    }
}
