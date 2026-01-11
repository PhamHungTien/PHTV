//
//  BeepManager.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit

// MARK: - Beep Manager

@MainActor
final class BeepManager {
    static let shared = BeepManager()

    private let popSound: NSSound?

    private init() {
        self.popSound = NSSound(named: NSSound.Name("Pop"))
        self.popSound?.loops = false
    }

    func play(volume: Double) {
        let v = max(0.0, min(1.0, volume))
        guard v > 0.0 else { return }
        if let sound = self.popSound {
            sound.stop()
            sound.volume = Float(v)
            sound.play()
            return
        }
        NSSound.beep()
    }
}
