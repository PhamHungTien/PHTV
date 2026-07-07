//
//  PHTVSendSequenceService.swift
//  PHTV
//
//  Shared execution-plan helpers for step-by-step synthetic text sending.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Darwin
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

    /// Runs `send(index)` for each item with CLI-aware pacing: scaled
    /// inter-item delays between sends and a post-send input block when the
    /// target is a CLI app. Non-CLI targets send without delays.
    class func sendItemsStepByStep(count: Int, send: (Int) -> Void) {
        guard count > 0 else { return }

        let isCli = PHTVEventRuntimeContextService.isCliTargetEnabled()
        var scaledCliTextDelayUs: UInt64 = 0
        var scaledCliPostSendBlockUs: UInt64 = 0
        if isCli {
            let cliSpeedFactor = PHTVCliRuntimeStateService.currentSpeedFactor()
            scaledCliTextDelayUs = UInt64(PHTVTimingService.scaleDelayUseconds(
                PHTVTimingService.clampToUseconds(PHTVCliRuntimeStateService.cliTextDelayUs()),
                factor: cliSpeedFactor))
            scaledCliPostSendBlockUs = PHTVTimingService.scaleDelayMicroseconds(
                PHTVCliRuntimeStateService.cliPostSendBlockUs(),
                factor: cliSpeedFactor)
        }

        let sendPlan = sequencePlan(
            forCliTarget: isCli,
            itemCount: Int32(count),
            scaledCliTextDelayUs: Int64(scaledCliTextDelayUs),
            scaledCliPostSendBlockUs: Int64(scaledCliPostSendBlockUs))
        let interItemDelayUs = PHTVTimingService.clampToUseconds(
            UInt64(max(Int64(0), sendPlan.interItemDelayUs)))

        for index in 0..<count {
            send(index)
            if interItemDelayUs > 0 && index + 1 < count {
                usleep(interItemDelayUs)
            }
        }

        if sendPlan.shouldScheduleCliBlock {
            PHTVCliRuntimeStateService.scheduleBlock(
                forMicroseconds: UInt64(max(Int64(0), sendPlan.cliBlockUs)),
                nowMachTime: mach_absolute_time())
        }
    }
}
