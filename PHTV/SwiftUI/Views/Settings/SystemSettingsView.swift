//
//  SystemSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct SystemSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingResetAlert = false
    @State private var showingConvertTool = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingImportConfirm = false
    @State private var importData: SettingsBackup?
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showSuccess = false
    @State private var successMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Startup Settings
                SettingsCard(title: "Khởi động", icon: "power.circle.fill") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "play.fill",
                            iconColor: .accentColor,
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
                                        .fill(Color.accentColor.opacity(0.12))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color.accentColor)
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
                            iconColor: .accentColor,
                            title: "Kênh Beta",
                            subtitle: "Nhận bản cập nhật beta (không ổn định)",
                            isOn: $appState.betaChannelEnabled
                        )

                        SettingsDivider()

                        // Manual check
                        SettingsButtonRow(
                            icon: "arrow.clockwise.circle.fill",
                            iconColor: .accentColor,
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
                            iconColor: .accentColor,
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
                            icon: "square.and.arrow.up.fill",
                            iconColor: .accentColor,
                            title: "Xuất cài đặt",
                            subtitle: "Sao lưu toàn bộ cài đặt ra file",
                            action: {
                                showingExportSheet = true
                            }
                        )

                        SettingsDivider()

                        SettingsButtonRow(
                            icon: "square.and.arrow.down.fill",
                            iconColor: .accentColor,
                            title: "Nhập cài đặt",
                            subtitle: "Khôi phục cài đặt từ file sao lưu",
                            action: {
                                showingImportSheet = true
                            }
                        )

                        SettingsDivider()

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
        .fileExporter(
            isPresented: $showingExportSheet,
            document: SettingsBackupDocument(backup: createBackup()),
            contentType: .json,
            defaultFilename: "phtv-backup-\(formatDate(Date())).json"
        ) { result in
            if case .failure(let error) = result {
                errorMessage = "Không thể xuất file: \(error.localizedDescription)"
                showError = true
            } else {
                successMessage = "Đã xuất cài đặt thành công!"
                showSuccess = true
            }
        }
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Nhập cài đặt?", isPresented: $showingImportConfirm) {
            Button("Hủy", role: .cancel) {
                importData = nil
            }
            Button("Nhập") {
                if let backup = importData {
                    applyBackup(backup)
                }
            }
        } message: {
            if let backup = importData {
                Text("Bản sao lưu từ \(backup.exportDate)\n• \(backup.macros?.count ?? 0) gõ tắt\n\nCài đặt hiện tại sẽ được thay thế.")
            }
        }
        .alert("Lỗi", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .alert("Thành công", isPresented: $showSuccess) {
            Button("OK") {}
        } message: {
            Text(successMessage)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func createBackup() -> SettingsBackup {
        let defaults = UserDefaults.standard

        // Collect all settings
        var settings: [String: AnyCodableValue] = [:]
        let settingsKeys = [
            "inputMethod", "codeTable", "checkSpelling", "restoreIfWrongSpelling",
            "quickTelex", "modernOrthography", "autoCapsMacro", "quickEndConsonant",
            "quickStartConsonant", "zAsConsonant", "freeMark", "fixChromiumBrowser",
            "sendKeyStepByStep", "autoRestoreEnglish", "useMacro", "macroInEnglish",
            "SwitchKeyStatus", "runOnStartup", "showIconOnDock", "themeColorHex",
            "updateCheckFrequency", "betaChannelEnabled"
        ]

        for key in settingsKeys {
            if let value = defaults.object(forKey: key) {
                settings[key] = AnyCodableValue(value)
            }
        }

        // Load macros
        var macros: [MacroItem]?
        if let data = defaults.data(forKey: "macroList"),
           let items = try? JSONDecoder().decode([MacroItem].self, from: data) {
            macros = items
        }

        // Load categories
        var categories: [MacroCategory]?
        if let data = defaults.data(forKey: "macroCategories"),
           let items = try? JSONDecoder().decode([MacroCategory].self, from: data) {
            categories = items
        }

        // Load excluded apps
        var excludedApps: [String]?
        if let apps = defaults.stringArray(forKey: "excludedApps") {
            excludedApps = apps
        }

        return SettingsBackup(
            version: "1.0",
            exportDate: ISO8601DateFormatter().string(from: Date()),
            settings: settings,
            macros: macros,
            macroCategories: categories,
            excludedApps: excludedApps
        )
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Không thể truy cập file"
                showError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let backup = try JSONDecoder().decode(SettingsBackup.self, from: data)
                importData = backup
                showingImportConfirm = true
            } catch {
                errorMessage = "File không hợp lệ: \(error.localizedDescription)"
                showError = true
            }

        case .failure(let error):
            errorMessage = "Không thể mở file: \(error.localizedDescription)"
            showError = true
        }
    }

    private func applyBackup(_ backup: SettingsBackup) {
        let defaults = UserDefaults.standard

        // Apply settings
        if let settings = backup.settings {
            for (key, value) in settings {
                defaults.set(value.value, forKey: key)
            }
        }

        // Apply macros
        if let macros = backup.macros {
            if let encoded = try? JSONEncoder().encode(macros) {
                defaults.set(encoded, forKey: "macroList")
            }
        }

        // Apply categories
        if let categories = backup.macroCategories {
            if let encoded = try? JSONEncoder().encode(categories) {
                defaults.set(encoded, forKey: "macroCategories")
            }
        }

        // Apply excluded apps
        if let excludedApps = backup.excludedApps {
            defaults.set(excludedApps, forKey: "excludedApps")
        }

        defaults.synchronize()

        // Reload all settings
        appState.loadSettings()

        // Notify all components
        NotificationCenter.default.post(name: NSNotification.Name("MacrosUpdated"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("CustomDictionaryUpdated"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("ExcludedAppsChanged"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("PHTVSettingsChanged"), object: nil)

        importData = nil
        successMessage = "Đã nhập cài đặt thành công!"
        showSuccess = true
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

// MARK: - Settings Backup Models

struct SettingsBackup: Codable, Sendable {
    let version: String
    let exportDate: String
    var settings: [String: AnyCodableValue]?
    var macros: [MacroItem]?
    var macroCategories: [MacroCategory]?
    var excludedApps: [String]?
}

struct AnyCodableValue: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else {
            try container.encode("")
        }
    }
}

struct SettingsBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var backup: SettingsBackup

    init(backup: SettingsBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        backup = SettingsBackup(version: "1.0", exportDate: "")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SystemSettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 600)
}
