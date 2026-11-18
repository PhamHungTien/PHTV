//
//  PHTVEventTapWatchdogService.swift
//  PHTV
//
//  Detects keystrokes that reach applications without passing through the
//  PHTV event tap, then rebuilds the tap in-process.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import CoreGraphics
import Foundation
import os

/// Pure decision logic for the keystroke watchdog.
///
/// The PHTV tap sits at the head of the session. A global key monitor only
/// sees events after they have passed every session tap. Each physical keyDown the observer sees has
/// already gone through the PHTV tap if that tap is alive, so the PHTV tap's
/// latest timestamp is at least as recent as the observed event. When several
/// physical keystrokes in a row arrive without the PHTV tap having seen them,
/// the tap is disabled, detached from its run loop or stuck: typing still
/// works but stays unaccented until the tap is rebuilt (issues #238, #242).
struct PHTVKeystrokeWatchdogState {
    static let missThreshold = 3
    static let recoveryCooldown: TimeInterval = 4

    private(set) var lastMainTapTimestamp: UInt64 = 0
    private(set) var consecutiveMisses = 0
    private(set) var lastRecoveryUptime: TimeInterval?
    private(set) var recoveryCount = 0
    /// True when the latest observed keystroke bypassed the PHTV tap.
    private(set) var lastObservationMissed = false

    mutating func noteMainTap(timestamp: UInt64) {
        if timestamp > lastMainTapTimestamp {
            lastMainTapTimestamp = timestamp
        }
    }

    /// Returns true when the PHTV tap should be recovered now.
    mutating func observePhysicalKeyDown(timestamp: UInt64, uptime: TimeInterval) -> Bool {
        if lastMainTapTimestamp >= timestamp {
            consecutiveMisses = 0
            lastObservationMissed = false
            return false
        }

        lastObservationMissed = true
        consecutiveMisses += 1
        guard consecutiveMisses >= Self.missThreshold else {
            return false
        }
        if let lastRecoveryUptime,
           uptime >= lastRecoveryUptime,
           uptime - lastRecoveryUptime < Self.recoveryCooldown {
            return false
        }

        consecutiveMisses = 0
        lastRecoveryUptime = uptime
        recoveryCount += 1
        return true
    }
}

final class PHTVEventTapWatchdogService {
    private static let decision = OSAllocatedUnfairLock(initialState: PHTVKeystrokeWatchdogState())

    /// Main-tap hook: called for every keyDown the PHTV tap receives. Must stay
    /// allocation-free; it runs on the keystroke hot path.
    static func noteMainTapKeyDown(timestamp: UInt64) {
        decision.withLock { $0.noteMainTap(timestamp: timestamp) }
    }

    static var recoveryCount: Int {
        decision.withLock { $0.recoveryCount }
    }

    // An NSEvent global monitor sees key events only after they have been
    // routed past the session event taps, and it needs no permission beyond
    // the Accessibility access PHTV already has (unlike a second CGEvent tap,
    // which could ask for Input Monitoring).
    @MainActor private static var monitor: Any?

    @MainActor static var isObserving: Bool {
        monitor != nil
    }

    /// Thread-safe copy for diagnostics gathered off the main actor.
    private static let observingFlag = OSAllocatedUnfairLock(initialState: false)
    static var isObservingSnapshot: Bool {
        observingFlag.withLock { $0 }
    }

    /// Starts the observer once. Safe to call repeatedly.
    @MainActor
    @discardableResult
    static func start() -> Bool {
        if monitor != nil { return true }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard let cgEvent = event.cgEvent else { return }
            PHTVEventTapWatchdogService.handleObserved(cgEvent)
        }
        let started = monitor != nil
        observingFlag.withLock { $0 = started }
        if started {
            NSLog("[EventTapWatchdog] Observer started")
        }
        return started
    }

    @MainActor
    static func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        observingFlag.withLock { $0 = false }
    }

    @MainActor
    private static func handleObserved(_ event: CGEvent) {
        guard event.getIntegerValueField(.eventSourceUserData) != EventSourceMarker.phtv,
              // Only physical keyboards: synthetic events posted by other apps
              // below the PHTV tap must not count as missed keystrokes.
              event.getIntegerValueField(.eventSourceStateID)
                == Int64(CGEventSourceStateID.hidSystemState.rawValue) else {
            return
        }

        let timestamp = event.timestamp
        let uptime = ProcessInfo.processInfo.systemUptime
        let (shouldRecover, missed) = decision.withLock { state in
            let recover = state.observePhysicalKeyDown(timestamp: timestamp, uptime: uptime)
            return (recover, state.lastObservationMissed)
        }
        if shouldRecover {
            PHTVEventTapService.recoverFromMissedKeystrokes()
        } else if missed {
            // The app received this key but the engine did not: continuing the
            // current word would turn the next keys into "oư" or "dd". Start a
            // fresh word instead.
            PHTVEngineSessionService.requestNewSessionInternal(allowUppercasePrime: false)
        }
    }
}
