//
//  PHTVKeyboardCleaningService.swift
//  PHTV
//
//  Temporarily blocks physical keyboard events so users can clean the keyboard.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import ApplicationServices
import Foundation

struct PHTVKeyboardCleaningSnapshot: Equatable, Sendable {
    let isActive: Bool
    let startedAt: Date?
    let endsAt: Date?
    let durationSeconds: TimeInterval
    let remainingSeconds: Int

    var progress: Double {
        guard isActive, durationSeconds > 0 else {
            return isActive ? 1 : 0
        }
        return min(max(1 - (Double(remainingSeconds) / durationSeconds), 0), 1)
    }
}

@objc final class PHTVKeyboardCleaningService: NSObject {
    private struct State {
        var startedAt: Date?
        var endsAt: Date?
        var durationSeconds: TimeInterval = Defaults.keyboardCleaningDuration

        var isActive: Bool {
            startedAt != nil && endsAt != nil
        }

        mutating func clear() {
            startedAt = nil
            endsAt = nil
        }
    }

    private final class StateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var state = State()

        func withLock<T>(_ body: (inout State) -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body(&state)
        }
    }

    private static let stateBox = StateBox()
    private static let minimumDurationSeconds: TimeInterval = 15
    private static let maximumDurationSeconds: TimeInterval = 600

    @discardableResult
    class func startCleaning(durationSeconds: TimeInterval) -> PHTVKeyboardCleaningSnapshot {
        startCleaning(durationSeconds: durationSeconds, now: Date())
    }

    @discardableResult
    class func startCleaning(
        durationSeconds: TimeInterval,
        now: Date
    ) -> PHTVKeyboardCleaningSnapshot {
        let clampedDuration = min(
            max(durationSeconds, minimumDurationSeconds),
            maximumDurationSeconds
        )
        let snapshot = stateBox.withLock { state in
            state.startedAt = now
            state.endsAt = now.addingTimeInterval(clampedDuration)
            state.durationSeconds = clampedDuration
            return makeSnapshot(from: state, now: now)
        }
        postStateChanged(snapshot)
        return snapshot
    }

    @discardableResult
    class func stopCleaning() -> PHTVKeyboardCleaningSnapshot {
        let now = Date()
        let snapshot = stateBox.withLock { state in
            state.clear()
            return makeSnapshot(from: state, now: now)
        }
        postStateChanged(snapshot)
        return snapshot
    }

    @objc class func isCleaningActive() -> Bool {
        snapshot().isActive
    }

    class func snapshot(now: Date = Date()) -> PHTVKeyboardCleaningSnapshot {
        stateBox.withLock { state in
            clearIfExpired(&state, now: now)
            return makeSnapshot(from: state, now: now)
        }
    }

    class func shouldBlockKeyboardEvent(type: CGEventType, now: Date = Date()) -> Bool {
        guard type == .keyDown || type == .keyUp || type == .flagsChanged else {
            return false
        }

        return stateBox.withLock { state in
            clearIfExpired(&state, now: now)
            guard let endsAt = state.endsAt else {
                return false
            }
            return now < endsAt
        }
    }

    private class func clearIfExpired(_ state: inout State, now: Date) {
        guard let endsAt = state.endsAt, now >= endsAt else {
            return
        }
        state.clear()
    }

    private class func makeSnapshot(from state: State, now: Date) -> PHTVKeyboardCleaningSnapshot {
        guard state.isActive, let endsAt = state.endsAt else {
            return PHTVKeyboardCleaningSnapshot(
                isActive: false,
                startedAt: nil,
                endsAt: nil,
                durationSeconds: state.durationSeconds,
                remainingSeconds: 0
            )
        }

        let remaining = max(0, Int(ceil(endsAt.timeIntervalSince(now))))
        return PHTVKeyboardCleaningSnapshot(
            isActive: remaining > 0,
            startedAt: state.startedAt,
            endsAt: endsAt,
            durationSeconds: state.durationSeconds,
            remainingSeconds: remaining
        )
    }

    private class func postStateChanged(_ snapshot: PHTVKeyboardCleaningSnapshot) {
        NotificationCenter.default.post(
            name: NotificationName.keyboardCleaningStateChanged,
            object: snapshot
        )
    }
}
