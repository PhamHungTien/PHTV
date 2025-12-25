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
    @State private var showingUpdateStatus = false
    @State private var updateStatusMessage = ""

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

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "app.fill",
                            iconColor: themeManager.themeColor,
                            title: "Hiển thị icon trên Dock",
                            subtitle: "Hiện icon PHTV khi mở menu bảng điều khiển",
                            isOn: $appState.showIconOnDock
                        )
                    }
                }

                // Appearance Settings
                SettingsCard(title: "Giao diện", icon: "paintbrush.fill") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "flag.fill",
                            iconColor: themeManager.themeColor,
                            title: "Hiển thị icon chữ V trên thanh menu",
                            subtitle: "Dùng icon chữ V khi đang ở chế độ tiếng Việt",
                            isOn: $appState.useVietnameseMenubarIcon
                        )

                        SettingsDivider()

                        VStack(spacing: 8) {
                            HStack(spacing: 14) {
                                ZStack {
                                    if #available(macOS 26.0, *) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(themeManager.themeColor.opacity(0.12))
                                            .frame(width: 36, height: 36)
                                            .glassEffect(in: .rect(cornerRadius: 8))
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(themeManager.themeColor.opacity(0.12))
                                            .frame(width: 36, height: 36)
                                    }

                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(themeManager.themeColor)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Kích cỡ icon thanh menu")
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    Text("Điều chỉnh kích thước icon trên thanh menu")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(String(format: "%.0f px", appState.menuBarIconSize))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tint)
                                    .frame(minWidth: 40, alignment: .trailing)
                            }

                            CustomSlider(
                                value: $appState.menuBarIconSize,
                                range: 12.0...20.0,
                                step: 0.01,
                                tintColor: themeManager.themeColor
                            )
                        }
                        .padding(.vertical, 6)
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
                            iconColor: themeManager.themeColor,
                            title: "Sửa lỗi Chromium",
                            subtitle: "Tương thích Chrome, Edge, Brave...",
                            isOn: $appState.fixChromiumBrowser
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "keyboard.fill",
                            iconColor: themeManager.themeColor,
                            title: "Tương thích bố cục bàn phím",
                            subtitle: "Hỗ trợ các bố cục đặc biệt",
                            isOn: $appState.performLayoutCompat
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
                            iconColor: .orange,
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
                resetToDefaults()
            }
        } message: {
            Text("Tất cả cài đặt sẽ được khôi phục về mặc định. Hành động này không thể hoàn tác.")
        }
        .alert("Kiểm tra cập nhật", isPresented: $showingUpdateStatus) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(updateStatusMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SparkleNoUpdateFound"))) { _ in
            updateStatusMessage = "Phiên bản hiện tại (\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")) đã là mới nhất"
            showingUpdateStatus = true
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
        // Show immediate feedback
        updateStatusMessage = "Đang kiểm tra cập nhật..."
        showingUpdateStatus = true

        // Trigger Sparkle update check
        // Sparkle will handle the UI via UpdateBannerView or show alert when no update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(
                name: NSNotification.Name("SparkleManualCheck"),
                object: nil
            )
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
        .frame(width: 500, height: 600)
}
