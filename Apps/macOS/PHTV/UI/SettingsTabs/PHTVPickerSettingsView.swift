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

                SettingsCard(
                    title: "Quyền riêng tư GIF & Sticker",
                    icon: "hand.raised.fill"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Emoji được xử lý hoàn toàn trên máy. Chỉ khi bạn mở hoặc tìm GIF/Sticker, PHTV mới kết nối với Klipy để tải nội dung và đo lượt hiển thị quảng cáo.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 14) {
                            if let privacyURL = URL(string: "https://github.com/PhamHungTien/PHTV/blob/main/docs/PRIVACY.md") {
                                Link("Chính sách riêng tư PHTV", destination: privacyURL)
                            }
                            if let klipyURL = URL(string: "https://klipy.com/support/privacy-policy") {
                                Link("Chính sách Klipy", destination: klipyURL)
                            }
                        }
                        .font(.callout)
                    }
                }

                Spacer(minLength: SettingsLayout.sectionSpacing)
            }
            .settingsPageFrame()
        }
        .settingsBackground()
    }
}

#Preview {
    PHTVPickerSettingsView()
        .environment(AppState.shared)
        .frame(width: 500, height: 520)
}
