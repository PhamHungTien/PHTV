//
//  PHTVTransientTextInsertionService.swift
//  PHTV
//
//  Reliable whole-text insertion for editors that drop long synthetic streams.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Foundation

enum PHTVTransientTextInsertionService {
    private struct PasteboardValue: Sendable {
        let type: String
        let data: Data
    }

    private struct PasteboardItemSnapshot: Sendable {
        let values: [PasteboardValue]
    }

    private final class StateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var active = false

        func begin() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard !active else { return false }
            active = true
            return true
        }

        func finish() {
            lock.lock()
            active = false
            lock.unlock()
        }

        func isActive() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return active
        }
    }

    private static let state = StateBox()
    private static let restoreDelay: TimeInterval = 0.25
    private static let monitorSettleDelay: TimeInterval = 0.55

    static var isPasteboardMutationActive: Bool {
        state.isActive()
    }

    static func insert(_ text: String) -> Bool {
        guard !text.isEmpty, state.begin() else {
            return false
        }

        let pasteboard = NSPasteboard.general
        guard let snapshot = snapshot(of: pasteboard) else {
            state.finish()
            return false
        }

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            restore(snapshot, to: pasteboard)
            finishAfterMonitorSettles()
            return false
        }

        let temporaryChangeCount = pasteboard.changeCount
        guard PHTVKeyEventSenderService.sendPasteShortcut() else {
            restore(snapshot, to: pasteboard)
            finishAfterMonitorSettles()
            return false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            let currentPasteboard = NSPasteboard.general
            guard currentPasteboard.changeCount == temporaryChangeCount else {
                // A real user copy always wins over restoring our snapshot.
                state.finish()
                return
            }

            restore(snapshot, to: currentPasteboard)
            finishAfterMonitorSettles()
        }

        return true
    }

    private static func snapshot(of pasteboard: NSPasteboard) -> [PasteboardItemSnapshot]? {
        guard let items = pasteboard.pasteboardItems else {
            return []
        }

        var snapshots: [PasteboardItemSnapshot] = []
        snapshots.reserveCapacity(items.count)
        for item in items {
            var values: [PasteboardValue] = []
            values.reserveCapacity(item.types.count)
            for type in item.types {
                guard let data = item.data(forType: type) else {
                    // Do not risk losing a promised/unsupported clipboard type.
                    return nil
                }
                values.append(PasteboardValue(type: type.rawValue, data: data))
            }
            snapshots.append(PasteboardItemSnapshot(values: values))
        }
        return snapshots
    }

    private static func restore(
        _ snapshots: [PasteboardItemSnapshot],
        to pasteboard: NSPasteboard
    ) {
        pasteboard.clearContents()
        guard !snapshots.isEmpty else { return }

        let items = snapshots.map { snapshot -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for value in snapshot.values {
                item.setData(value.data, forType: NSPasteboard.PasteboardType(value.type))
            }
            return item
        }
        pasteboard.writeObjects(items)
    }

    private static func finishAfterMonitorSettles() {
        DispatchQueue.main.asyncAfter(deadline: .now() + monitorSettleDelay) {
            state.finish()
        }
    }
}
