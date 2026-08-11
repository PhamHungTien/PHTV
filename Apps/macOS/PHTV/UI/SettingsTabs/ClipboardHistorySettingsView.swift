//
//  ClipboardHistorySettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct ClipboardHistorySettingsView: View {
    var manager = ClipboardHistoryManager.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: SettingsLayout.sectionSpacing) {
                SettingsCard(
                    title: "Lịch sử Clipboard",
                    icon: "doc.on.clipboard.fill"
                ) {
                    ClipboardHotkeyConfigView()
                }

                SettingsCard(
                    title: "Mục đã lưu",
                    subtitle: "Nội dung cố định được sắp xếp theo nhóm và không bị xoá cùng lịch sử.",
                    icon: "bookmark.fill",
                    displaysSubtitle: true
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Label("\(manager.savedLibrary.items.count) mục", systemImage: "bookmark")
                                .foregroundStyle(.secondary)
                            Label("\(manager.savedLibrary.groups.count) nhóm", systemImage: "folder")
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button("Mở Mục đã lưu") {
                                manager.show(section: .saved)
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Label(
                            "Dữ liệu được lưu cục bộ nhưng không được mã hoá. Không dùng cho mật khẩu, mã OTP hoặc khoá bí mật.",
                            systemImage: "lock.open.trianglebadge.exclamationmark"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
    ClipboardHistorySettingsView()
        .environment(AppState.shared)
        .frame(width: 500, height: 560)
}
