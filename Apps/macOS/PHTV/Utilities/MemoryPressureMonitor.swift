//
//  MemoryPressureMonitor.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

/// Clears transient caches when the system is under memory pressure.
@MainActor
final class MemoryPressureMonitor {
    static let shared = MemoryPressureMonitor()

    private var source: DispatchSourceMemoryPressure?

    private init() {}

    func start() {
        guard source == nil else { return }
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        self.source = source
        source.resume()
    }

    private func handleMemoryPressure() {
        AppIconCache.shared.clear()
        URLCache.shared.removeAllCachedResponses()
        NSLog("[MemoryPressure] Cleared caches")
    }
}
