//
//  SystemSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct SystemSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingResetAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Startup Settings
                SettingsCard(title: "Khởi động", icon: "power.circle.fill") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "play.fill",
                            iconColor: .green,
                            title: "Khởi động cùng hệ thống",
                            subtitle: "Tự động mở PHTV khi đăng nhập macOS",
                            isOn: $appState.runOnStartup
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "app.fill",
                            iconColor: .blue,
                            title: "Hiển thị icon trên Dock",
                            subtitle: "Hiện icon PHTV khi mở menu bảng điều khiển",
                            isOn: $appState.showIconOnDock
                        )
                    }
                }

                // Excluded Apps
                SettingsCard(title: "Loại trừ ứng dụng", icon: "app.badge.fill") {
                    ExcludedAppsView()
                }

                // Compatibility Settings
                SettingsCard(title: "Tương thích", icon: "puzzlepiece.extension.fill") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "globe",
                            iconColor: .blue,
                            title: "Sửa lỗi Chromium",
                            subtitle: "Tương thích Chrome, Edge, Brave...",
                            isOn: $appState.fixChromiumBrowser
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "keyboard.fill",
                            iconColor: .purple,
                            title: "Tương thích bố cục bàn phím",
                            subtitle: "Hỗ trợ các bố cục đặc biệt",
                            isOn: $appState.performLayoutCompat
                        )
                    }
                }

                // App Information
                SettingsCard(title: "Thông tin ứng dụng", icon: "info.circle.fill") {
                    VStack(spacing: 0) {
                        SettingsInfoRow(
                            icon: "number.circle.fill",
                            iconColor: .blue,
                            title: "Phiên bản",
                            value: Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                                as? String ?? "1.0"
                        )

                        SettingsDivider()

                        SettingsInfoRow(
                            icon: "hammer.fill",
                            iconColor: .orange,
                            title: "Build",
                            value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                        )

                        SettingsDivider()

                        SettingsButtonRow(
                            icon: "arrow.clockwise.circle.fill",
                            iconColor: .green,
                            title: "Kiểm tra cập nhật",
                            subtitle: "Tìm phiên bản mới",
                            action: {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("CheckForUpdates"), object: nil)
                            }
                        )
                    }
                }

                // Data Management
                SettingsCard(title: "Quản lý dữ liệu", icon: "externaldrive.fill") {
                    VStack(spacing: 0) {
                        SettingsButtonRow(
                            icon: "arrow.counterclockwise.circle.fill",
                            iconColor: .red,
                            title: "Đặt lại cài đặt",
                            subtitle: "Khôi phục mặc định",
                            isDestructive: true,
                            action: {
                                showingResetAlert = true
                            }
                        )
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Đặt lại cài đặt?", isPresented: $showingResetAlert) {
            Button("Hủy", role: .cancel) {}
            Button("Đặt lại", role: .destructive) {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.loadDefaultConfig()
                    appState.loadSettings()
                }
            }
        } message: {
            Text("Tất cả cài đặt sẽ được khôi phục về mặc định. Hành động này không thể hoàn tác.")
        }
    }
}

// MARK: - Settings Row Components

struct SettingsInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct SettingsButtonRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(isDestructive ? .red : .primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SystemSettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 600)
}
