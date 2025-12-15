//
//  BeepManager.swift
//  PHTV
//
//  Created by Copilot.
//

import AppKit

@MainActor
final class BeepManager {
    static let shared = BeepManager()

    private let sound: NSSound?

    private init() {
        self.sound = NSSound(named: NSSound.Name("Pop"))
        self.sound?.loops = false
    }

    func play(volume: Double) {
        let v = max(0.0, min(1.0, volume))
        guard v > 0.0 else { return }
        if let sound = self.sound {
            sound.stop()
            sound.volume = Float(v)
            sound.play()
            return
        }
        NSBeep()
    }
}
