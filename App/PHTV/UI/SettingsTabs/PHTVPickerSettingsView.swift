//
//  PHTVPickerSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct PHTVPickerSettingsView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: SettingsLayout.sectionSpacing) {
                SettingsCard(
                    title: "PHTV Picker",
                    icon: "smiley.fill"
                ) {
                    EmojiHotkeyConfigView()
                }

                Spacer(minLength: SettingsLayout.sectionSpacing)
            }
            .frame(maxWidth: .infinity)
            .padding(SettingsLayout.contentPadding)
        }
        .settingsBackground()
    }
}

#Preview {
    PHTVPickerSettingsView()
        .environment(AppState.shared)
        .frame(width: 500, height: 520)
}
