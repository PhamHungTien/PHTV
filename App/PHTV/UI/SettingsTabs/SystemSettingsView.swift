//
//  SystemSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

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
    @State private var showOnboarding = false
    @State private var exportBackup = SettingsBackup(version: "2.0", exportDate: "")

    private static let isoFormatter = ISO8601DateFormatter()

    private var menuBarIconSizeBounds: ClosedRange<Double> {
        let minSize = 12.0
        let nativeCap = Double(NSStatusBar.system.thickness - 4.0)
        let maxSize = max(minSize, nativeCap)
        return minSize...maxSize
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                SettingsHeaderView(
                    title: "Hệ thống & Cập nhật",
                    subtitle: "Quản lý giao diện, khởi động, cập nhật và sao lưu.",
                    icon: "gearshape.fill"
                ) {
                    VStack(alignment: .trailing, spacing: 6) {
                        SettingsStatusPill(
                            text: appState.runOnStartup ? "Tự khởi động: Bật" : "Tự khởi động: Tắt",
                            color: appState.runOnStartup ? .accentColor : .secondary
                        )
                        SettingsStatusPill(
                            text: appState.showIconOnDock ? "Dock: Hiện" : "Dock: Ẩn",
                            color: appState.showIconOnDock ? .compatTeal : .secondary
                        )
                    }
                }

                interfaceSection
                menuBarSection
                dockSection
                startupSection
                updateSection
                toolsSection
                dataManagementSection

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .settingsBackground()
        .sheet(isPresented: $showingConvertTool) {
            ConvertToolView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationName.showConvertToolSheet)) { _ in
            showingConvertTool = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationName.openConvertToolSheet)) { _ in
            showingConvertTool = true
        }
        .alert("Khôi phục mặc định?", isPresented: $showingResetAlert) {
            Button("Hủy", role: .cancel) {}
            Button("Khôi phục", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("Tất cả cài đặt sẽ được đưa về mặc định. Hành động này không thể hoàn tác.")
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: SettingsBackupDocument(backup: exportBackup),
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
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(onDismiss: {
                showOnboarding = false
            })
            .environmentObject(appState)
        }
    }

    private var startupSection: some View {
        SettingsCard(
            title: "Khởi động",
            subtitle: "Tùy chọn tự mở khi đăng nhập",
            icon: "power.circle.fill"
        ) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "play.fill",
                    iconColor: .accentColor,
                    title: "Mở cùng hệ thống",
                    subtitle: "Tự động mở PHTV khi đăng nhập macOS",
                    isOn: $appState.runOnStartup
                )
            }
        }
    }

    private var interfaceSection: some View {
        SettingsCard(
            title: "Giao diện",
            subtitle: "Tùy chỉnh hiển thị cửa sổ",
            icon: "rectangle.on.rectangle"
        ) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "pin.fill",
                    iconColor: .accentColor,
                    title: "Cài đặt luôn ở trên",
                    subtitle: "Giữ cửa sổ Cài đặt nằm trên các ứng dụng khác",
                    isOn: $appState.settingsWindowAlwaysOnTop
                )
            }
        }
    }

    private var menuBarSection: some View {
        SettingsCard(
            title: "Thanh menu",
            subtitle: "Tùy chỉnh biểu tượng trên menu bar",
            icon: "menubar.rectangle"
        ) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "flag.fill",
                    iconColor: .accentColor,
                    title: "Hiển thị biểu tượng chữ V",
                    subtitle: "Dùng icon chữ V khi đang ở chế độ Tiếng Việt",
                    isOn: $appState.useVietnameseMenubarIcon
                )

                SettingsDivider()

                SettingsSliderRow(
                    icon: "arrow.up.left.and.arrow.down.right",
                    iconColor: .accentColor,
                    title: "Kích thước icon",
                    subtitle: "Điều chỉnh kích thước icon trên menu bar",
                    minValue: menuBarIconSizeBounds.lowerBound,
                    maxValue: menuBarIconSizeBounds.upperBound,
                    step: 0.1,
                    value: $appState.menuBarIconSize,
                    valueFormatter: { String(format: "%.1f px", $0) }
                )
            }
        }
    }

    private var dockSection: some View {
        SettingsCard(
            title: "Dock",
            subtitle: "Tùy chọn hiển thị trên Dock",
            icon: "dock.rectangle"
        ) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "app.fill",
                    iconColor: .accentColor,
                    title: "Hiện icon trên Dock",
                    subtitle: "Hiển thị PHTV trên Dock khi mở Cài đặt",
                    isOn: $appState.showIconOnDock
                )
            }
        }
    }

    private var updateSection: some View {
        SettingsCard(
            title: "Cập nhật",
            subtitle: "Thiết lập kiểm tra cập nhật",
            icon: "arrow.down.circle.fill"
        ) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tần suất kiểm tra cập nhật")
                            .font(.system(size: 13))

                        Text("Tự động kiểm tra bản cập nhật mới")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Picker("", selection: $appState.updateCheckFrequency) {
                        ForEach(UpdateCheckFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 130)
                }
                .padding(.vertical, 5)

                SettingsDivider()

                SettingsButtonRow(
                    icon: "arrow.clockwise.circle.fill",
                    iconColor: .accentColor,
                    title: "Kiểm tra ngay",
                    subtitle: "Tìm phiên bản mới ngay bây giờ",
                    action: checkForUpdates
                )
            }
        }
    }

    private var toolsSection: some View {
        SettingsCard(
            title: "Tiện ích",
            subtitle: "Các công cụ đi kèm",
            icon: "wrench.and.screwdriver.fill"
        ) {
            VStack(spacing: 0) {
                SettingsButtonRow(
                    icon: "doc.on.clipboard.fill",
                    iconColor: .accentColor,
                    title: "Chuyển đổi bảng mã",
                    subtitle: "Chuyển văn bản giữa Unicode, TCVN3, VNI…",
                    action: {
                        showingConvertTool = true
                    }
                )
            }
        }
    }

    private var dataManagementSection: some View {
        SettingsCard(
            title: "Dữ liệu & sao lưu",
            subtitle: "Sao lưu, khôi phục và đặt lại",
            icon: "externaldrive.fill"
        ) {
            VStack(spacing: 0) {
                SettingsButtonRow(
                    icon: "book.fill",
                    iconColor: .accentColor,
                    title: "Xem lại hướng dẫn",
                    subtitle: "Mở lại phần giới thiệu PHTV",
                    action: {
                        showOnboarding = true
                    }
                )

                SettingsDivider()

                SettingsButtonRow(
                    icon: "square.and.arrow.up.fill",
                    iconColor: .accentColor,
                    title: "Xuất cấu hình",
                    subtitle: "Sao lưu toàn bộ cài đặt ra file",
                    action: {
                        exportBackup = createBackup()
                        showingExportSheet = true
                    }
                )

                SettingsDivider()

                SettingsButtonRow(
                    icon: "square.and.arrow.down.fill",
                    iconColor: .accentColor,
                    title: "Nhập cấu hình",
                    subtitle: "Khôi phục cài đặt từ file sao lưu",
                    action: {
                        showingImportSheet = true
                    }
                )

                SettingsDivider()

                SettingsButtonRow(
                    icon: "arrow.counterclockwise.circle.fill",
                    iconColor: .red,
                    title: "Khôi phục mặc định",
                    subtitle: "Đưa toàn bộ cài đặt về mặc định",
                    isDestructive: true,
                    action: {
                        showingResetAlert = true
                    }
                )
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func decodeStoredValue<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func saveStoredValue<T: Encodable>(_ value: T, key: String, defaults: UserDefaults) {
        guard let encoded = try? JSONEncoder().encode(value) else { return }
        defaults.set(encoded, forKey: key)
    }

    private func createBackup() -> SettingsBackup {
        let defaults = UserDefaults.standard

        // Collect all settings with correct UserDefaults keys
        var settings: [String: AnyCodableValue] = [:]
        let settingsKeys = [
            // Input method & code table
            UserDefaultsKey.inputType, UserDefaultsKey.codeTable,

            // System settings
            UserDefaultsKey.runOnStartup, UserDefaultsKey.performLayoutCompat, UserDefaultsKey.showIconOnDock,
            UserDefaultsKey.settingsWindowAlwaysOnTop, UserDefaultsKey.safeMode,

            // Switch key (hotkey)
            UserDefaultsKey.switchKeyStatus,

            // Input behavior
            UserDefaultsKey.spelling, UserDefaultsKey.modernOrthography, UserDefaultsKey.quickTelex,
            UserDefaultsKey.sendKeyStepByStep, UserDefaultsKey.useMacro, UserDefaultsKey.useMacroInEnglishMode, UserDefaultsKey.autoCapsMacro,
            UserDefaultsKey.useSmartSwitchKey, UserDefaultsKey.upperCaseFirstChar, UserDefaultsKey.allowConsonantZFWJ,
            UserDefaultsKey.quickStartConsonant, UserDefaultsKey.quickEndConsonant, UserDefaultsKey.rememberCode,

            // Auto restore English
            UserDefaultsKey.autoRestoreEnglishWord,

            // Restore key
            UserDefaultsKey.restoreOnEscape, UserDefaultsKey.customEscapeKey,

            // Pause key
            UserDefaultsKey.pauseKeyEnabled, UserDefaultsKey.pauseKey, UserDefaultsKey.pauseKeyName,

            // Emoji hotkey
            UserDefaultsKey.enableEmojiHotkey, UserDefaultsKey.emojiHotkeyModifiers, UserDefaultsKey.emojiHotkeyKeyCode,

            // Audio & display
            UserDefaultsKey.beepOnModeSwitch, UserDefaultsKey.beepVolume, UserDefaultsKey.menuBarIconSize, UserDefaultsKey.useVietnameseMenubarIcon,

            // Update settings
            UserDefaultsKey.updateCheckInterval,

            // Bug report settings
            UserDefaultsKey.includeSystemInfo, UserDefaultsKey.includeLogs, UserDefaultsKey.includeCrashLogs
        ]

        for key in settingsKeys {
            if let value = defaults.object(forKey: key) {
                settings[key] = AnyCodableValue(value)
            }
        }

        // Load macros
        var macros: [MacroItem]?
        if defaults.data(forKey: UserDefaultsKey.macroList) != nil {
            macros = MacroStorage.load(defaults: defaults)
        }

        // Load categories
        let categories: [MacroCategory]? = decodeStoredValue(
            [MacroCategory].self,
            key: UserDefaultsKey.macroCategories,
            defaults: defaults
        )

        // Load excluded apps (new format)
        let excludedAppsV2: [ExcludedApp]? = decodeStoredValue(
            [ExcludedApp].self,
            key: UserDefaultsKey.excludedApps,
            defaults: defaults
        )

        // Load send key step by step apps
        let stepByStepApps: [ExcludedApp]? = decodeStoredValue(
            [ExcludedApp].self,
            key: UserDefaultsKey.sendKeyStepByStepApps,
            defaults: defaults
        )

        // Load uppercase excluded apps
        let upperCaseExcludedApps: [ExcludedApp]? = decodeStoredValue(
            [ExcludedApp].self,
            key: UserDefaultsKey.upperCaseExcludedApps,
            defaults: defaults
        )

        return SettingsBackup(
            version: "2.0",
            exportDate: Self.isoFormatter.string(from: Date()),
            settings: settings,
            macros: macros,
            macroCategories: categories,
            excludedApps: nil,  // Legacy format no longer used
            excludedAppsV2: excludedAppsV2,
            sendKeyStepByStepApps: stepByStepApps,
            upperCaseExcludedApps: upperCaseExcludedApps
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
        SettingsObserver.shared.suspendNotifications(for: 1.0)
        let defaults = UserDefaults.standard

        // Apply settings
        if let settings = backup.settings {
            for (key, value) in settings {
                defaults.set(value.value, forKey: key)
            }
        }

        // Auto-install updates is always ON and beta channel is not supported.
        defaults.enforceStableUpdateChannel()

        // Apply macros
        if let macros = backup.macros {
            _ = MacroStorage.save(macros, defaults: defaults)
        }

        // Apply categories
        if let categories = backup.macroCategories {
            saveStoredValue(categories, key: UserDefaultsKey.macroCategories, defaults: defaults)
        }

        // Apply excluded apps (prefer new format, fallback to legacy)
        if let excludedAppsV2 = backup.excludedAppsV2 {
            // New format with full app info
            saveStoredValue(excludedAppsV2, key: UserDefaultsKey.excludedApps, defaults: defaults)
        } else if let excludedApps = backup.excludedApps {
            // Legacy format: convert bundle IDs to ExcludedApp objects
            let apps = excludedApps.map { bundleId in
                ExcludedApp(
                    bundleIdentifier: bundleId,
                    name: bundleId.components(separatedBy: ".").last ?? bundleId,
                    path: ""
                )
            }
            saveStoredValue(apps, key: UserDefaultsKey.excludedApps, defaults: defaults)
        }

        // Apply send key step by step apps
        if let stepByStepApps = backup.sendKeyStepByStepApps {
            saveStoredValue(stepByStepApps, key: UserDefaultsKey.sendKeyStepByStepApps, defaults: defaults)
        }

        // Apply uppercase excluded apps
        if let upperCaseExcludedApps = backup.upperCaseExcludedApps {
            saveStoredValue(upperCaseExcludedApps, key: UserDefaultsKey.upperCaseExcludedApps, defaults: defaults)
        }


        // Reload all settings
        appState.loadSettings()

        // Notify all components
        NotificationCenter.default.post(name: NotificationName.macrosUpdated, object: nil)
        NotificationCenter.default.post(name: NotificationName.customDictionaryUpdated, object: nil)
        NotificationCenter.default.post(name: NotificationName.excludedAppsChanged, object: nil)
        NotificationCenter.default.post(name: NotificationName.upperCaseExcludedAppsChanged, object: nil)
        NotificationCenter.default.post(name: NotificationName.phtvSettingsChanged, object: nil)
        NotificationCenter.default.post(
            name: NotificationName.hotkeyChanged,
            object: NSNumber(value: defaults.integer(forKey: UserDefaultsKey.switchKeyStatus))
        )
        NotificationCenter.default.post(name: NotificationName.emojiHotkeySettingsChanged, object: nil)

        importData = nil
        successMessage = "Đã nhập cài đặt thành công!"
        showSuccess = true
    }

    private func resetToDefaults() {
        // Reset via AppState (single source of truth)
        appState.resetToDefaults()
    }

    private func checkForUpdates() {
        PHTVLogger.shared.ui("[SystemSettings] User clicked 'Kiểm tra cập nhật' button")

        // Trigger Sparkle update check
        // Sparkle will handle the UI via UpdateBannerView or notification when no update
        NotificationCenter.default.post(
            name: NotificationName.sparkleManualCheck,
            object: nil
        )

        PHTVLogger.shared.ui("[SystemSettings] Posted SparkleManualCheck notification")
    }
}

// MARK: - Settings Row Components

struct SettingsInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Compact icon
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
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
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                // Compact icon
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                        .frame(width: 24, height: 24)
                        .tint(iconColor)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(iconColor)
                        .frame(width: 24, height: 24)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(isDestructive ? .red : .primary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if !isLoading {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .background(hoverBackground)
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(subtitle))
        .onHover { hovering in
            isHovered = hovering
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .animation(nil, value: isHovered)
    }

    @ViewBuilder
    private var hoverBackground: some View {
        if isHovered {
            PHTVRoundedRect(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.03))
                .padding(.horizontal, -4)
                .padding(.vertical, -2)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Settings Backup Models

struct SettingsBackup: Codable, Sendable {
    let version: String
    let exportDate: String
    var settings: [String: AnyCodableValue]?
    var macros: [MacroItem]?
    var macroCategories: [MacroCategory]?
    var excludedApps: [String]?  // Legacy format (bundle IDs only)
    var excludedAppsV2: [ExcludedApp]?  // New format with full app info
    var sendKeyStepByStepApps: [ExcludedApp]?  // Apps with step-by-step key sending
    var upperCaseExcludedApps: [ExcludedApp]?  // Apps excluded from uppercase first char
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
