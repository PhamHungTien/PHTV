//
//  CompatibilitySettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import Observation

struct CompatibilitySettingsView: View {
    @Environment(AppState.self) private var appState
    private var bindable: Bindable<AppState> { Bindable(appState) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: SettingsLayout.sectionSpacing) {
                // Keyboard Layout Compatibility
                SettingsCard(
                    title: "Bàn phím",
                    subtitle: "Hỗ trợ bố cục đặc biệt",
                    icon: "keyboard.fill"
                ) {
                    SettingsToggleRow(
                        icon: "keyboard.fill",
                        iconColor: .accentColor,
                        title: "Tương thích bố cục bàn phím",
                        subtitle: "Hỗ trợ Dvorak, Colemak và các bố cục đặc biệt",
                        isOn: bindable.performLayoutCompat
                    )
                }

                Spacer(minLength: SettingsLayout.sectionSpacing)
            }
            .settingsPageFrame()
        }
        .settingsBackground()
    }
}

#Preview {
    CompatibilitySettingsView()
        .environment(AppState.shared)
        .frame(width: 500, height: 600)
}
