//
//  SettingsWindowOpener.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

@MainActor
final class SettingsWindowOpener: ObservableObject {
    static let shared = SettingsWindowOpener()

    func requestOpenWindow() {
        SettingsWindowHelper.openSettingsWindow()
    }
}
