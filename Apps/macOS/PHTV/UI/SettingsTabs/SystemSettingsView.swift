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
import ServiceManagement
import Observation

struct SystemSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingResetAlert = false
    @State private var showingConvertTool = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingImportConfirm = false
    @State private var showingUninstallAlert = false
    @State private var isUninstalling = false
    @State private var importData: SettingsBackup?
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var showOnboarding = false
    @State private var exportBackup = SettingsBackup(version: SettingsBackup.currentVersion, exportDate: "")
    private var bindable: Bindable<AppState> { Bindable(appState) }

    private var menuBarIconSizeBounds: ClosedRange<Double> {
        let minSize = 12.0
        let nativeCap = Double(NSStatusBar.system.thickness - 4.0)
        let maxSize = max(minSize, nativeCap)
        return minSize...maxSize
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: SettingsLayout.sectionSpacing) {
                interfaceSection
                menuBarSection
                dockSection
                startupSection
                updateSection
                toolsSection
                dataManagementSection

                Spacer(minLength: SettingsLayout.sectionSpacing)
            }
            .settingsPageFrame()
        }
        .settingsBackground()
        .sheet(isPresented: $showingConvertTool) {
            ConvertToolView()
        }
        .task {
            await observeConvertToolNotification(named: NotificationName.showConvertToolSheet)
        }
        .task {
            await observeConvertToolNotification(named: NotificationName.openConvertToolSheet)
        }
        .alert("Khôi phục mặc định?", isPresented: $showingResetAlert) {
            Button("Hủy", role: .cancel) {}
            Button("Khôi phục", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("Tất cả cài đặt sẽ được đưa về mặc định. Hành động này không thể hoàn tác.")
        }
        .alert("Gỡ cài đặt PHTV?", isPresented: $showingUninstallAlert) {
            Button("Hủy", role: .cancel) {}
            Button("Gỡ cài đặt", role: .destructive) {
                uninstallPHTV()
            }
        } message: {
            Text("PHTV sẽ tắt, xoá ứng dụng cùng toàn bộ cài đặt, dữ liệu cục bộ, cache, log và dữ liệu tạm liên quan. Hành động này không thể hoàn tác.")
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: SettingsBackupDocument(backup: exportBackup),
            contentType: .json,
            defaultFilename: "phtv-backup-\(formatDate(Date())).json"
        ) { result in
            if case .failure(let error) = result {
                if (error as? CocoaError)?.code == .userCancelled { return }
                errorMessage = "Không thể xuất file: \(error.localizedDescription)"
                showError = true
            } else {
                successMessage = "Đã xuất dữ liệu thành công!" + externalFilesWarning(exportBackup)
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
                Text("Bản sao lưu từ \(backup.exportDate)\n• \(backup.macros?.count ?? 0) gõ tắt\n• \(backup.clipboardHistory?.count ?? 0) mục lịch sử Clipboard\n• \(backup.clipboardLibrary?.items.count ?? 0) mục đã lưu\n\nCác phần có trong file sẽ thay thế dữ liệu tương ứng. File cũ không xóa phần bị thiếu.")
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
            .environment(appState)
        }
    }

    @MainActor
    private func observeConvertToolNotification(named name: Notification.Name) async {
        for await _ in NotificationCenter.default.notifications(named: name) {
            guard !Task.isCancelled else { return }
            showingConvertTool = true
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
                    isOn: bindable.runOnStartup
                )

                SettingsDivider()

                SettingsToggleRow(
                    icon: "arrow.clockwise",
                    iconColor: .accentColor,
                    title: "Tự động khởi động lại khi đóng Cài đặt",
                    subtitle: "Giải phóng RAM bằng cách khởi động lại ứng dụng mỗi khi đóng cửa sổ Cài đặt",
                    isOn: bindable.autoRestartOnSettingsClose
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
                    isOn: bindable.settingsWindowAlwaysOnTop
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
                    isOn: bindable.useVietnameseMenubarIcon
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
                    value: bindable.menuBarIconSize,
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
                    isOn: bindable.showIconOnDock
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
                SettingsPickerRow(
                    title: "Tần suất kiểm tra cập nhật",
                    subtitle: "Tự động kiểm tra bản cập nhật mới",
                    selection: bindable.updateCheckFrequency,
                    controlWidth: 150
                ) {
                    ForEach(UpdateCheckFrequency.allCases) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }

                SettingsDivider()

                SettingsToggleRow(
                    icon: "arrow.down.to.line.circle.fill",
                    iconColor: .accentColor,
                    title: "Tự động tải và cài đặt",
                    subtitle: "Tự động áp dụng các bản cập nhật mới nhất",
                    isOn: bindable.autoInstallUpdates
                )

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
                    subtitle: "Sao lưu cài đặt, gõ tắt và dữ liệu Clipboard",
                    action: {
                        do {
                            appState.flushPendingSettingsForWindowClose()
                            try ClipboardHistoryManager.shared.validateBackupReadiness()
                            exportBackup = try SettingsBackupService().create()
                            exportBackup.smartSwitchData = PHTVSmartSwitchRuntimeService.snapshotData()
                            showingExportSheet = true
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
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

                SettingsDivider()

                SettingsButtonRow(
                    icon: "trash.fill",
                    iconColor: .red,
                    title: "Gỡ cài đặt PHTV",
                    subtitle: "Xoá ứng dụng, cài đặt, cache, log và dữ liệu cục bộ",
                    isDestructive: true,
                    isLoading: isUninstalling,
                    action: {
                        showingUninstallAlert = true
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

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            do {
                let backup = try SettingsBackupService.read(url)
                importData = backup
                showingImportConfirm = true
            } catch {
                errorMessage = "File không hợp lệ: \(error.localizedDescription)"
                showError = true
            }

        case .failure(let error):
            if (error as? CocoaError)?.code == .userCancelled { return }
            errorMessage = "Không thể mở file: \(error.localizedDescription)"
            showError = true
        }
    }

    private func externalFilesWarning(_ backup: SettingsBackup) -> String {
        guard backup.externalFileReferenceCount > 0 else { return "" }
        return "\nCó \(backup.externalFileReferenceCount) tham chiếu tới file bên ngoài chưa được PHTV lưu bản sao; cần giữ hoặc chuyển các file gốc riêng."
    }

    private func applyBackup(_ backup: SettingsBackup) {
        SettingsObserver.shared.suspendNotifications(for: 1.0)
        let defaults = UserDefaults.standard

        appState.flushPendingSettingsForWindowClose()
        ClipboardMonitor.shared.stopMonitoring()
        defer {
            if appState.enableClipboardHistory { ClipboardMonitor.shared.startMonitoring() }
        }
        do {
            try SettingsBackupService().apply(backup)
        } catch {
            if error as? BackupError == .rollbackFailed { SettingsBackupService.stopToProtectData(after: error) }
            errorMessage = error.localizedDescription
            showError = true
            return
        }
        defaults.enforceStableUpdateChannel()
        PHTVSmartSwitchPersistenceService.invalidatePendingWrites()
        var systemWarning = ""
        if let requested = backup.settings?[UserDefaultsKey.runOnStartup] {
            do {
                let enabled = (requested.value as? NSNumber)?.boolValue ?? false
                if enabled {
                    if SMAppService.mainApp.status != .enabled && SMAppService.mainApp.status != .requiresApproval {
                        try SMAppService.mainApp.register()
                    }
                }
                else if SMAppService.mainApp.status != .notRegistered { try SMAppService.mainApp.unregister() }
                if SMAppService.mainApp.status == .requiresApproval {
                    systemWarning = "\nHãy cho phép khởi động cùng macOS trong Login Items."
                }
            } catch {
                systemWarning = "\nDữ liệu đã nhập, nhưng chưa áp dụng được Login Items: \(error.localizedDescription)"
            }
        }
        PHTVSmartSwitchRuntimeService.loadFromPersistedData()

        // Reload all settings
        appState.loadSettings()
        if backup.clipboardHistory != nil || backup.clipboardLibrary != nil {
            ClipboardHistoryManager.shared.reloadAfterBackupImport()
        }
        ClipboardItemHotkeyManager.shared.refreshRegistrations()
        if !ClipboardItemHotkeyManager.shared.unavailableHotkeys.isEmpty {
            systemWarning += "\nMột số phím tắt Clipboard đang trùng hoặc không khả dụng trên máy này; hãy kiểm tra lại trong Clipboard."
        }

        // Notify all components
        NotificationCenter.default.post(name: NotificationName.macrosUpdated, object: nil)
        NotificationCenter.default.post(name: NotificationName.customDictionaryUpdated, object: nil)
        NotificationCenter.default.post(name: NotificationName.excludedAppsChanged, object: nil)
        NotificationCenter.default.post(name: NotificationName.sendKeyStepByStepAppsChanged, object: nil)
        NotificationCenter.default.post(name: NotificationName.clipboardHotkeySettingsChanged, object: nil)
        NotificationCenter.default.post(name: NotificationName.upperCaseExcludedAppsChanged, object: nil)
        NotificationCenter.default.post(name: NotificationName.phtvSettingsChanged, object: nil)
        NotificationCenter.default.post(
            name: NotificationName.hotkeyChanged,
            object: NSNumber(value: defaults.integer(forKey: UserDefaultsKey.switchKeyStatus))
        )
        NotificationCenter.default.post(name: NotificationName.emojiHotkeySettingsChanged, object: nil)

        importData = nil
        successMessage = "Đã nhập dữ liệu thành công!" + systemWarning + externalFilesWarning(backup)
        showSuccess = true
    }

    private func resetToDefaults() {
        // Reset via AppState (single source of truth)
        appState.resetToDefaults()
    }

    private func uninstallPHTV() {
        guard !isUninstalling else { return }
        isUninstalling = true

        do {
            try PHTVUninstaller.scheduleCleanUninstall()
        } catch {
            isUninstalling = false
            errorMessage = error.localizedDescription
            showError = true
        }
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

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)

            Text(title)
                .font(.body)
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

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 24, height: 24)
                        .tint(iconColor)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(iconColor)
                        .frame(width: 24, height: 24)
                }

                Text(title)
                    .font(.body)
                    .foregroundStyle(isDestructive ? .red : .primary)
                    .lineLimit(1)

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
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(subtitle))
    }
}

// MARK: - Settings Backup Document
struct SettingsBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var backup: SettingsBackup

    init(backup: SettingsBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        backup = try SettingsBackupService.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try SettingsBackupSchema.validate(backup)
        let data = try encoder.encode(backup)
        guard data.count <= 512 * 1024 * 1024 else { throw BackupError.invalid("file vượt 512 MB") }
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SystemSettingsView()
        .environment(AppState.shared)
        .frame(width: 500, height: 600)
}
