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
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingResetAlert = false
    @State private var showingConvertTool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Startup Settings
                SettingsCard(title: "Khởi động", icon: "power.circle.fill") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "play.fill",
                            iconColor: themeManager.themeColor,
                            title: "Khởi động cùng hệ thống",
                            subtitle: "Tự động mở PHTV khi đăng nhập macOS",
                            isOn: $appState.runOnStartup
                        )
                    }
                }

                // Update Settings
                SettingsCard(title: "Cập nhật", icon: "arrow.down.circle.fill") {
                    VStack(spacing: 0) {
                        // Frequency picker
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeManager.themeColor.opacity(0.12))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(themeManager.themeColor)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tần suất kiểm tra")
                                        .font(.body)

                                    Text("Tự động kiểm tra bản cập nhật mới")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Picker("", selection: $appState.updateCheckFrequency) {
                                    ForEach(UpdateCheckFrequency.allCases) { freq in
                                        Text(freq.displayName).tag(freq)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 140)
                            }
                            .padding(.vertical, 6)
                        }

                        SettingsDivider()

                        // Beta toggle
                        SettingsToggleRow(
                            icon: "testtube.2",
                            iconColor: themeManager.themeColor,
                            title: "Kênh Beta",
                            subtitle: "Nhận bản cập nhật beta (không ổn định)",
                            isOn: $appState.betaChannelEnabled
                        )

                        SettingsDivider()

                        // Manual check
                        SettingsButtonRow(
                            icon: "arrow.clockwise.circle.fill",
                            iconColor: themeManager.themeColor,
                            title: "Kiểm tra cập nhật",
                            subtitle: "Tìm phiên bản mới ngay bây giờ",
                            action: checkForUpdates
                        )
                    }
                }

                // Tools
                SettingsCard(title: "Công cụ", icon: "wrench.and.screwdriver.fill") {
                    VStack(spacing: 0) {
                        SettingsButtonRow(
                            icon: "doc.on.clipboard.fill",
                            iconColor: themeManager.themeColor,
                            title: "Chuyển đổi bảng mã",
                            subtitle: "Chuyển văn bản giữa Unicode, TCVN3, VNI...",
                            action: {
                                showingConvertTool = true
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
        .settingsBackground()
        .sheet(isPresented: $showingConvertTool) {
            ConvertToolView()
                .environmentObject(themeManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowConvertToolSheet"))) { _ in
            showingConvertTool = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenConvertToolSheet"))) { _ in
            showingConvertTool = true
        }
        .alert("Đặt lại cài đặt?", isPresented: $showingResetAlert) {
            Button("Hủy", role: .cancel) {}
            Button("Đặt lại", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("Tất cả cài đặt sẽ được khôi phục về mặc định. Hành động này không thể hoàn tác.")
        }
    }

    private func resetToDefaults() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            // Reset all settings to defaults in UserDefaults (synchronous)
            // This also updates global variables and calls fillData()
            appDelegate.loadDefaultConfig()

            // Reload AppState properties immediately from UserDefaults
            // This triggers SwiftUI to update the UI immediately
            appState.loadSettings()

            // Post notification to trigger UI refresh across the app
            NotificationCenter.default.post(name: NSNotification.Name("SettingsReset"), object: nil)
        }
    }

    private func checkForUpdates() {
        print("[SystemSettings] User clicked 'Kiểm tra cập nhật' button")

        // Trigger Sparkle update check
        // Sparkle will handle the UI via UpdateBannerView or notification when no update
        NotificationCenter.default.post(
            name: NSNotification.Name("SparkleManualCheck"),
            object: nil
        )

        print("[SystemSettings] Posted SparkleManualCheck notification")
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
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)

                    if isLoading {
                        ProgressView()
                            .tint(iconColor)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(iconColor)
                    }
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

                if !isLoading {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

#Preview {
    SystemSettingsView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
        .frame(width: 500, height: 600)
}
