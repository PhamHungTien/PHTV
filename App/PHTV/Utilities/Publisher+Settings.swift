//
//  Publisher+Settings.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Combine

extension Publisher where Failure == Never {
    /// Skips the initial `@Published` emission so the first real user interaction is never
    /// coalesced away by downstream debounce operators.
    func settingsChangeEvent() -> AnyPublisher<Void, Never> {
        dropFirst()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}
