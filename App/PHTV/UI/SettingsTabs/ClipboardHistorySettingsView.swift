//
//  ClipboardHistorySettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct ClipboardHistorySettingsView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: SettingsLayout.sectionSpacing) {
                SettingsCard(
                    title: "Lịch sử Clipboard",
                    icon: "doc.on.clipboard.fill"
                ) {
                    ClipboardHotkeyConfigView()
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
    ClipboardHistorySettingsView()
        .environment(AppState.shared)
        .frame(width: 500, height: 560)
}
