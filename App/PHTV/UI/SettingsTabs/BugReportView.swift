//
//  BugReportView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import OSLog
import Carbon
import Darwin.Mach
import UniformTypeIdentifiers
import Observation

// MARK: - Logger for PHTV
private let phtvLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.phamhungtien.phtv", category: "general")
private let phtvMarkdownContentType = UTType(filenameExtension: "md") ?? .plainText

private enum BugSeverity: String, CaseIterable, Identifiable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Nhẹ"
        case .normal: return "Bình thường"
        case .high: return "Nghiêm trọng"
        case .critical: return "Khẩn cấp"
        }
    }

    var badge: String {
        switch self {
        case .low: return "🟢"
        case .normal: return "🟡"
        case .high: return "🟠"
        case .critical: return "🔴"
        }
    }
}

private enum BugArea: String, CaseIterable, Identifiable {
    case typing = "typing"
    case hotkey = "hotkey"
    case menuBar = "menubar"
    case settings = "settings"
    case picker = "picker"
    case macro = "macro"
    case compatibility = "compatibility"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .typing: return "Gõ tiếng Việt"
        case .hotkey: return "Hotkey"
        case .menuBar: return "Menu bar"
        case .settings: return "Cài đặt"
        case .picker: return "Emoji/Picker"
        case .macro: return "Macro"
        case .compatibility: return "Tương thích app"
        case .other: return "Khác"
        }
    }
}

struct BugReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    private var bindable: Bindable<AppState> { Bindable(appState) }

    @State private var bugTitle: String = ""
    @State private var bugDescription: String = ""
    @State private var stepsToReproduce: String = ""
    @State private var expectedResult: String = ""
    @State private var actualResult: String = ""
    @State private var contactEmail: String = ""
    @State private var bugSeverity: BugSeverity = .normal
    @State private var bugArea: BugArea = .typing
    @State private var logBuffer: String = ""
    @State private var isLoadingLogs: Bool = false
    @State private var showCopiedAlert: Bool = false
    @State private var showSavedAlert: Bool = false
    @State private var showSaveErrorAlert: Bool = false
    @State private var savedLocation: String = ""
    @State private var saveErrorMessage: String = ""
    // Default: OFF to avoid loading heavy OSLog snapshot when chỉ xem tab
    @State private var showLogPreview: Bool = false
    @State private var isSending: Bool = false
    @State private var hasLoadedLogsOnce: Bool = false
    @State private var showOptionalDetails: Bool = false
    @State private var showingSaveReportSheet: Bool = false
    @State private var reportDocument = BugReportDocument(text: "")

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                SettingsHeaderView(
                    title: "Báo lỗi & Hỗ trợ",
                    subtitle: "Gửi thông tin chi tiết để hỗ trợ nhanh và chính xác.",
                    icon: "ladybug.fill"
                )

                // Bug Information Form
                bugInfoSection

                // Debug Options & Info
                debugOptionsSection

                // Actions
                actionsSection

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .settingsBackground()
        .alert("Đã sao chép", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nội dung báo lỗi đã được sao chép.")
        }
        .alert("Đã lưu báo cáo", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(savedLocation.isEmpty ? "Đã lưu báo cáo." : "Đã lưu tại: \(savedLocation)")
        }
        .alert("Không thể lưu báo cáo", isPresented: $showSaveErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .fileExporter(
            isPresented: $showingSaveReportSheet,
            document: reportDocument,
            contentType: phtvMarkdownContentType,
            defaultFilename: "phtv-bug-report.md"
        ) { result in
            switch result {
            case .success(let url):
                savedLocation = url.lastPathComponent
                showSavedAlert = true
            case .failure(let error):
                if (error as? CocoaError)?.code == .userCancelled {
                    return
                }
                saveErrorMessage = "Không thể lưu file: \(error.localizedDescription)"
                showSaveErrorAlert = true
            }
        }
        .onChange(of: appState.includeLogs) { _, newValue in
            if newValue {
                // Load log khi người dùng bật, tránh chiếm RAM nếu không cần
                Task { await loadLogsIfNeeded() }
            } else {
                // Giải phóng bộ nhớ log khi tắt
                logBuffer = ""
                showLogPreview = false
            }
        }
        .onDisappear {
            // Giải phóng log khi rời tab để hạ RAM
            logBuffer = ""
        }
    }

    // MARK: - Bug Info Section
    private var bugInfoSection: some View {
        SettingsCard(
            title: "Thông tin sự cố",
            subtitle: "Chỉ cần tiêu đề và mô tả",
            icon: "ladybug.fill"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bạn chỉ cần nhập tiêu đề và mô tả. Các mục khác là tuỳ chọn.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Bug Title
                TextField("Tiêu đề vấn đề (vd: Không gõ được tiếng Việt trong Safari)", text: $bugTitle)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background {
                        inputFieldBackground(cornerRadius: 8)
                    }

                // Description
                TextEditor(text: $bugDescription)
                    .frame(minHeight: 100)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background {
                        inputFieldBackground(cornerRadius: 8)
                    }
                    .clipShape(PHTVRoundedRect(cornerRadius: 8))
                    .overlay(alignment: .topLeading) {
                        if bugDescription.isEmpty {
                            Text("Mô tả ngắn gọn vấn đề. Có thể kèm bước tái hiện nếu muốn…")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                DisclosureGroup(isExpanded: $showOptionalDetails) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Các mục dưới đây giúp chẩn đoán nhanh hơn (không bắt buộc).")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Mức độ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("", selection: $bugSeverity) {
                                    ForEach(BugSeverity.allCases) { severity in
                                        Text("\(severity.badge) \(severity.displayName)").tag(severity)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .glassMenuPickerStyle()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Khu vực")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("", selection: $bugArea) {
                                    ForEach(BugArea.allCases) { area in
                                        Text(area.displayName).tag(area)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .glassMenuPickerStyle()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        Text("Bước tái hiện")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $stepsToReproduce)
                            .frame(minHeight: 80)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background {
                                inputFieldBackground(cornerRadius: 8)
                            }
                            .clipShape(PHTVRoundedRect(cornerRadius: 8))
                            .overlay(alignment: .topLeading) {
                                if stepsToReproduce.isEmpty {
                                    Text("1. Mở ứng dụng...\n2. Thực hiện...\n3. Lỗi xảy ra...")
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 16)
                                        .allowsHitTesting(false)
                                }
                            }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Kết quả mong muốn")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextEditor(text: $expectedResult)
                                    .frame(minHeight: 70)
                                    .font(.body)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background {
                                        inputFieldBackground(cornerRadius: 8)
                                    }
                                    .clipShape(PHTVRoundedRect(cornerRadius: 8))
                                    .overlay(alignment: .topLeading) {
                                        if expectedResult.isEmpty {
                                            Text("Ứng dụng nên…")
                                                .foregroundStyle(.tertiary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 16)
                                                .allowsHitTesting(false)
                                        }
                                    }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Kết quả thực tế")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextEditor(text: $actualResult)
                                    .frame(minHeight: 70)
                                    .font(.body)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background {
                                        inputFieldBackground(cornerRadius: 8)
                                    }
                                    .clipShape(PHTVRoundedRect(cornerRadius: 8))
                                    .overlay(alignment: .topLeading) {
                                        if actualResult.isEmpty {
                                            Text("Thực tế đang…")
                                                .foregroundStyle(.tertiary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 16)
                                                .allowsHitTesting(false)
                                        }
                                }
                            }
                        }
                        TextField("Email liên hệ (tuỳ chọn)", text: $contactEmail)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background {
                                inputFieldBackground(cornerRadius: 8)
                            }
                    }
                    .padding(.top, 4)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Thêm chi tiết (tuỳ chọn)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Debug Options Section
    private var debugOptionsSection: some View {
        SettingsCard(
            title: "Thông tin chẩn đoán",
            subtitle: "Hệ thống và nhật ký",
            icon: "doc.text.fill"
        ) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "cpu.fill",
                    iconColor: .accentColor,
                    title: "Thông tin hệ thống",
                    subtitle: "Phiên bản PHTV, macOS, chip và bàn phím",
                    isOn: bindable.includeSystemInfo
                )

                SettingsDivider()

                SettingsToggleRow(
                    icon: "doc.text.fill",
                    iconColor: .accentColor,
                    title: "Nhật ký (tùy chọn)",
                    subtitle: appState.includeLogs ? "Đang thu thập log 60 phút gần nhất" : "Chỉ tải khi cần để tiết kiệm RAM",
                    isOn: bindable.includeLogs
                )

                if appState.includeLogs {
                    SettingsDivider()
                    HStack(spacing: 10) {
                        if isLoadingLogs {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: hasLoadedLogsOnce ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                .foregroundStyle(hasLoadedLogsOnce ? Color.green : Color.accentColor)
                        }
                        Text(hasLoadedLogsOnce ? "Đã tải log — tắt/bật để làm mới" : "Bật để tải log (tối đa 100 mục)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)

                    HStack(spacing: 12) {
                        Button {
                            Task { await refreshLogs() }
                        } label: {
                            Label("Làm mới log", systemImage: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .disabled(isLoadingLogs)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showLogPreview.toggle()
                            }
                            if showLogPreview {
                                Task { await loadLogsIfNeeded() }
                            }
                        } label: {
                            Label(showLogPreview ? "Ẩn xem trước" : "Xem trước log", systemImage: showLogPreview ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)

                        Spacer()
                    }

                    if showLogPreview {
                        TextEditor(text: .constant(logPreviewText))
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 140)
                            .roundedTextArea()
                            .disabled(true)
                    }
                }

                SettingsDivider()

                SettingsToggleRow(
                    icon: "bolt.fill",
                    iconColor: .accentColor,
                    title: "Crash logs gần đây",
                    subtitle: "Đính kèm các crash log PHTV trong 7 ngày",
                    isOn: bindable.includeCrashLogs
                )
            }
        }
    }

    // MARK: - Actions Section
    private var actionsSection: some View {
        SettingsCard(
            title: "Gửi báo lỗi",
            subtitle: "Chọn kênh gửi phù hợp",
            icon: "paperplane.fill"
        ) {
            HStack(spacing: 12) {
                // Copy to Clipboard
                Button {
                    Task { await copyBugReportToClipboardAsync() }
                } label: {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Sao chép báo lỗi", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                }
                .adaptiveBorderedButtonStyle()
                .controlSize(.large)
                .disabled(isSending)

                // Open GitHub Issue
                Button {
                    Task { await openGitHubIssueAsync() }
                } label: {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("GitHub", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                }
                .adaptiveProminentButtonStyle()
                .controlSize(.large)
                .tint(.accentColor)
                .disabled(isSending)

                // Send Email
                Button {
                    Task { await sendEmailReportAsync() }
                } label: {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Gửi email", systemImage: "envelope")
                            .frame(maxWidth: .infinity)
                    }
                }
                .adaptiveBorderedButtonStyle()
                .controlSize(.large)
                .disabled(isSending)
            }
            .padding(.vertical, 8)

            HStack(spacing: 10) {
                Button {
                    Task { await saveReportToFileAsync() }
                } label: {
                    Label("Lưu báo cáo…", systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(isSending)

                Button {
                    applyTemplateIfNeeded()
                } label: {
                    Label("Tạo mẫu", systemImage: "wand.and.stars")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(isSending)

                Spacer()

                Button(role: .destructive) {
                    clearForm()
                } label: {
                    Label("Xoá nội dung", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .disabled(isSending)
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Helper Views
    private func systemInfoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }

    // MARK: - Helper Functions
    private func getChipInfo() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &machine, &size, nil, 0)

        // Convert to String properly
        let cpuBrand: String
        if let nullIndex = machine.firstIndex(of: 0) {
            cpuBrand = String(decoding: machine[..<nullIndex].map { UInt8(bitPattern: $0) }, as: UTF8.self)
        } else {
            cpuBrand = String(decoding: machine.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }

        if cpuBrand.isEmpty {
            // Fallback for Apple Silicon
            #if arch(arm64)
            return "Apple Silicon"
            #else
            return "Intel"
            #endif
        }
        return cpuBrand.trimmingCharacters(in: .whitespaces)
    }

    private func getCurrentKeyboardLayout() -> String {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let localizedName = TISGetInputSourceProperty(inputSource, kTISPropertyLocalizedName) else {
            return "Unknown"
        }
        return Unmanaged<CFString>.fromOpaque(localizedName).takeUnretainedValue() as String
    }

    // MARK: - Runtime Info Helpers

    private func checkEventTapStatus() -> String {
        let hasPermission = PHTVManager.canCreateEventTap()
        let isInited = PHTVManager.isInited()
        if hasPermission && isInited {
            return "✅ Running"
        } else if hasPermission && !isInited {
            return "⚠️ Permission OK, tap not initialized"
        } else if appState.hasAccessibilityPermission {
            return "⚠️ Accessibility granted, event tap unavailable"
        } else {
            return "❌ No accessibility permission"
        }
    }

    private func getFrontAppInfo() -> String {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return "Unknown"
        }

        let appName = frontApp.localizedName ?? "Unknown"
        let bundleId = frontApp.bundleIdentifier ?? "Unknown"

        // Check if it's an excluded app
        let isExcluded = appState.excludedApps.contains { $0.bundleIdentifier == bundleId }
        let excludedMark = isExcluded ? " 🚫" : ""

        return "\(appName) (\(bundleId))\(excludedMark)"
    }

    private func getExcludedAppsDetails() -> String {
        guard !appState.excludedApps.isEmpty else {
            return ""
        }

        var details = "\n  **Danh sách:**\n"
        for app in appState.excludedApps.prefix(10) {
            details += "  - \(app.name) (\(app.bundleIdentifier))\n"
        }

        if appState.excludedApps.count > 10 {
            details += "  - ... và \(appState.excludedApps.count - 10) app khác\n"
        }

        return details
    }

    private func getPerformanceInfo() -> String {
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = processInfo.physicalMemory

        // Get process memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        let usedMemoryMB: Double
        if kerr == KERN_SUCCESS {
            usedMemoryMB = Double(info.resident_size) / 1024.0 / 1024.0
        } else {
            usedMemoryMB = 0
        }

        let totalMemoryGB = Double(physicalMemory) / 1024.0 / 1024.0 / 1024.0

        var output = ""
        output += "- **Memory Usage:** \(String(format: "%.1f MB", usedMemoryMB))\n"
        output += "- **Total RAM:** \(String(format: "%.1f GB", totalMemoryGB))\n"
        output += "- **Uptime:** \(formatUptime(processInfo.systemUptime))"

        return output
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func getBrowserDetectionInfo() -> String {
        var output = ""

        // Supported browsers
        let supportedBrowsers = [
            "Safari", "Chrome", "Firefox", "Edge", "Arc", "Brave",
            "Vivaldi", "Opera", "Chromium", "Cốc Cốc", "DuckDuckGo",
            "Orion", "Zen", "Dia"
        ]
        output += "- **Supported Browsers:** \(supportedBrowsers.joined(separator: ", "))\n"

        // Browser fix features
        output += "- **Browser Detection & Handling:**\n"
        output += "  - Detection method: ✅ Bundle ID matching (_browserAppSet)\n"
        output += "  - Event posting: ✅ CGEventTapPostEvent (standard)\n"
        output += "  - HID tap/AX API: ❌ Disabled for browsers (autocomplete incompatible)\n"
        output += "  - Backspace method: ✅ Standard SendBackspace() - no delays\n"
        output += "  - Address bar fix: ✅ Prevents Spotlight-style handling on browser\n"
        output += "  - Empty char timing: ✅ Smart detection (skips '/' shortcuts)\n"
        output += "  - Step-by-step mode: \(appState.sendKeyStepByStep ? "✅ Enabled (global)" : "❌ Disabled (default)")\n"
        output += "  - Auto English restore: \(appState.autoRestoreEnglishWord ? "✅ (HID tap for restoration)" : "❌")\n"
        output += "  - Auto restore mode: \(appState.autoRestoreEnglishWordMode.reportLabel)\n"

        // Current front app
        output += "- **Current App:** \(getFrontAppInfo())\n"

        // Terminal/IDE detection
        output += "- **Terminal/IDE Apps:** Auto-detected via bundle ID (iTerm2, Terminal, VS Code, etc.)\n"
        output += "- **Spotlight-like Apps:** Auto-detected via AX API + bundle ID\n"

        return output
    }

    private func getRecentCrashLogs() -> String {
        guard appState.includeCrashLogs else { return "" }
        let crashLogsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports")

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: crashLogsPath,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return ""
        }

        // Filter PHTV crash logs from last 7 days
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let phtvCrashes = files.filter { file in
            guard file.lastPathComponent.contains("PHTV") || file.lastPathComponent.contains("phtv") else {
                return false
            }

            if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate {
                return creationDate > sevenDaysAgo
            }
            return false
        }.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 > date2
        }

        guard !phtvCrashes.isEmpty else {
            return ""
        }

        var crashReport = "📍 Tìm thấy \(phtvCrashes.count) crash log(s) gần đây:\n\n"

        // Get first crash log content
        if let firstCrash = phtvCrashes.first,
           let content = try? String(contentsOf: firstCrash, encoding: .utf8) {
            crashReport += "**File:** \(firstCrash.lastPathComponent)\n\n"

            // Extract important parts
            let lines = content.components(separatedBy: .newlines)

            // Get crash reason
            if let crashReasonLine = lines.first(where: { $0.contains("Exception Type:") || $0.contains("Termination Reason:") }) {
                crashReport += "\(crashReasonLine)\n"
            }

            // Get thread that crashed
            var inCrashedThread = false
            var threadLines: [String] = []
            for line in lines {
                if line.contains("Thread") && line.contains("Crashed") {
                    inCrashedThread = true
                    threadLines.append(line)
                    continue
                }

                if inCrashedThread {
                    if line.starts(with: "Thread ") || line.isEmpty {
                        break
                    }
                    threadLines.append(line)
                    if threadLines.count > 15 { break }  // Limit to 15 lines
                }
            }

            if !threadLines.isEmpty {
                crashReport += "\n```\n"
                crashReport += threadLines.joined(separator: "\n")
                crashReport += "\n```\n"
            }
        }

        // List other crash files
        if phtvCrashes.count > 1 {
            crashReport += "\n**Các crash khác:**\n"
            for crash in phtvCrashes.dropFirst().prefix(3) {
                crashReport += "- \(crash.lastPathComponent)\n"
            }
        }

        return crashReport
    }

    private func loadDebugLogs() {
        guard !isLoadingLogs else { return }
        isLoadingLogs = true

        Task(priority: .userInitiated) {
            let logs = await Self.fetchLogsInBackground(maxEntries: 80)
            applyLoadedLogs(logs)
        }
    }

    private func loadDebugLogsAsync() async {
        guard !isLoadingLogs else { return }
        isLoadingLogs = true

        let logs = await Self.fetchLogsInBackground(maxEntries: 80)

        logBuffer = logs
        isLoadingLogs = false
        hasLoadedLogsOnce = true
    }

    private func loadLogsIfNeeded() async {
        if logBuffer.isEmpty {
            await loadDebugLogsAsync()
        }
    }

    private func refreshLogs() async {
        logBuffer = ""
        await loadDebugLogsAsync()
    }

    // MARK: - Log Entry Model
    private struct LogEntry {
        let date: Date
        let level: OSLogEntryLog.Level
        let category: String
        let message: String

        var levelString: String {
            switch level {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .notice: return "NOTICE"
            case .error: return "ERROR"
            case .fault: return "FAULT"
            default: return "LOG"
            }
        }

        var levelEmoji: String {
            switch level {
            case .error, .fault: return "🔴"
            case .notice: return "🟡"
            case .info: return "🔵"
            case .debug: return "⚪"
            default: return "⚫"
            }
        }

        var isImportant: Bool {
            level == .error || level == .fault || level == .notice
        }
    }

    // MARK: - Log Statistics
    private struct LogStats {
        var totalCount: Int = 0
        var errorCount: Int = 0
        var warningCount: Int = 0
        var infoCount: Int = 0
        var debugCount: Int = 0
        var firstLogTime: Date?
        var lastLogTime: Date?
        var lastError: String?
        var lastErrorTime: Date?
        var categoryCounts: [String: Int] = [:]

        var duration: String {
            guard let first = firstLogTime, let last = lastLogTime else { return "N/A" }
            let interval = last.timeIntervalSince(first)
            if interval < 60 {
                return "\(Int(interval)) giây"
            } else if interval < 3600 {
                return "\(Int(interval / 60)) phút"
            } else {
                return String(format: "%.1f giờ", interval / 3600)
            }
        }
    }

    nonisolated private static func fetchLogsSync(maxEntries: Int = 100) -> String {
        var allLogEntries: [LogEntry] = []
        var stats = LogStats()

        // 1. Lấy log từ OSLogStore (unified logging)
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            // Lấy log trong 15 phút gần đây để giảm RAM khi mở tab
            let position = store.position(date: Date().addingTimeInterval(-15 * 60))
            let entries = try store.getEntries(at: position)

            var regularLogCount = 0
            let maxRegularLogs = maxEntries
            let maxTotalLogs = maxEntries * 2

            for entry in entries {
                if let logEntry = entry as? OSLogEntryLog {
                    var message = logEntry.composedMessage
                    guard !message.isEmpty else { continue }

                    let isErrorOrWarning = logEntry.level == .error || logEntry.level == .fault || logEntry.level == .notice

                    // Lọc bỏ log hệ thống không liên quan
                    if shouldFilterOut(message: message, subsystem: logEntry.subsystem, level: logEntry.level) {
                        continue
                    }

                    // LUÔN giữ lại tất cả errors và warnings - không bao giờ bỏ sót
                    // Chỉ giới hạn số lượng log thường
                    if !isErrorOrWarning {
                        if regularLogCount >= maxRegularLogs {
                            continue // Bỏ qua log thường nếu đã đủ, nhưng vẫn tiếp tục tìm errors/warnings
                        }
                        regularLogCount += 1
                    }

                    if message.count > 400 {
                        message = String(message.prefix(400)) + "..."
                    }

                    let category = detectCategory(from: message)
                    let logEntryItem = LogEntry(
                        date: logEntry.date,
                        level: logEntry.level,
                        category: category,
                        message: message
                    )
                    allLogEntries.append(logEntryItem)

                    if allLogEntries.count >= maxTotalLogs {
                        break
                    }
                }
            }
        } catch {
            // Ignore OSLogStore errors, fallback to file logs
        }

        // 2. Lấy log từ file (nếu PHTVLogger được sử dụng)
        // Note: Thêm PHTVLogger.swift vào project để bật tính năng này
        // let fileLogs = PHTVLogger.shared.getFileLogs()
        // if !fileLogs.isEmpty { ... }

        // Sắp xếp theo thời gian
        allLogEntries.sort { $0.date < $1.date }

        // Tính thống kê
        for entry in allLogEntries {
            stats.totalCount += 1
            stats.categoryCounts[entry.category, default: 0] += 1

            if stats.firstLogTime == nil { stats.firstLogTime = entry.date }
            stats.lastLogTime = entry.date

            switch entry.level {
            case .error, .fault:
                stats.errorCount += 1
                stats.lastError = entry.message
                stats.lastErrorTime = entry.date
            case .notice:
                stats.warningCount += 1
            case .info:
                stats.infoCount += 1
            case .debug:
                stats.debugCount += 1
            default:
                break
            }
        }

        if allLogEntries.isEmpty {
            return buildNoLogsMessage()
        }

        return buildFormattedOutput(entries: allLogEntries, stats: stats, maxEntries: maxEntries)
    }

    nonisolated private static func fetchLogsInBackground(maxEntries: Int = 100) async -> String {
        autoreleasepool {
            fetchLogsSync(maxEntries: maxEntries)
        }
    }

    /// Lọc bỏ các log hệ thống không liên quan đến PHTV
    nonisolated private static func shouldFilterOut(message: String, subsystem: String, level: OSLogEntryLog.Level) -> Bool {
        // Luôn giữ lại ERROR và FAULT - quan trọng để debug
        if level == .error || level == .fault {
            // Nhưng lọc bỏ một số error hệ thống không liên quan
            let systemErrors = [
                "HALC_Proxy", "IOWorkLoop", "AddInstanceForFactory",
                "Reporter disconnected", "task name port"
            ]
            for pattern in systemErrors {
                if message.contains(pattern) {
                    return true
                }
            }
            return false
        }

        // Giữ lại log từ PHTV subsystem
        if subsystem.contains("phtv") || subsystem.contains("PHTV") {
            return false
        }

        // Giữ lại log có chứa từ khóa quan trọng của PHTV
        let keepPatterns = [
            "[PHTV", "PHTV]", "[phtv",
            "[Permission]", "[Accessibility]",
            "[SettingsView]", "[InputMethod]",
            "[Telex]", "[VNI]", "[Vietnamese]",
            "[Macro]", "[Backend]", "[Sync]",
            "PHTV Live", "PHTV_LIVE",
            "com.phamhungtien.phtv"
        ]

        for pattern in keepPatterns {
            if message.contains(pattern) {
                return false
            }
        }

        // Lọc bỏ tất cả log hệ thống khác
        return true
    }

    nonisolated private static func detectCategory(from message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("input") || lowercased.contains("key") || lowercased.contains("typing") {
            return "Input"
        } else if lowercased.contains("sync") || lowercased.contains("save") || lowercased.contains("load") {
            return "Sync"
        } else if lowercased.contains("ui") || lowercased.contains("view") || lowercased.contains("window") {
            return "UI"
        } else if lowercased.contains("error") || lowercased.contains("fail") || lowercased.contains("crash") {
            return "Error"
        } else if lowercased.contains("launch") || lowercased.contains("start") || lowercased.contains("init") {
            return "Startup"
        } else if lowercased.contains("macro") {
            return "Macro"
        } else if lowercased.contains("vietnamese") || lowercased.contains("telex") || lowercased.contains("vni") {
            return "VNInput"
        }
        return "General"
    }

    nonisolated private static func buildFormattedOutput(entries: [LogEntry], stats: LogStats, maxEntries: Int = 100) -> String {
        // Sử dụng mảng thay vì string concatenation để tăng hiệu năng
        var lines: [String] = []
        lines.reserveCapacity(maxEntries + 30)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        let fullDateFormatter = DateFormatter()
        fullDateFormatter.dateFormat = "dd/MM HH:mm:ss"

        // === THỐNG KÊ TỔNG QUAN (rút gọn) ===
        lines.append("📊 THỐNG KÊ: \(stats.totalCount) log | \(stats.duration)")

        if stats.errorCount > 0 {
            lines.append("🔴 Lỗi: \(stats.errorCount) | 🟡 Cảnh báo: \(stats.warningCount)")
        }

        // Lỗi gần nhất - QUAN TRỌNG
        if let lastError = stats.lastError, let errorTime = stats.lastErrorTime {
            lines.append("")
            lines.append("⚠️ LỖI GẦN NHẤT [\(fullDateFormatter.string(from: errorTime))]:")
            // Hiển thị đầy đủ lỗi (tối đa 10 dòng)
            let errorLines = lastError.components(separatedBy: .newlines)
            for line in errorLines.prefix(10) {
                lines.append("  \(line)")
            }
            if errorLines.count > 10 {
                lines.append("  ... (\(errorLines.count - 10) dòng nữa)")
            }
        }

        lines.append("")
        lines.append("───────────────────────────────────────")

        // === LỖI VÀ CẢNH BÁO (ưu tiên lỗi) ===
        let errorEntries = entries.filter { $0.level == .error || $0.level == .fault }
        let warningEntries = entries.filter { $0.level == .notice }

        if !errorEntries.isEmpty || !warningEntries.isEmpty {
            lines.append("🚨 LỖI VÀ CẢNH BÁO:")

            // Hiển thị tất cả lỗi (tối đa 20)
            if !errorEntries.isEmpty {
                lines.append("  📛 Lỗi (\(errorEntries.count)):")
                for entry in errorEntries.suffix(20) {
                    let time = dateFormatter.string(from: entry.date)
                    lines.append("  🔴 [\(time)] \(entry.message)")
                }
            }

            // Hiển thị cảnh báo (tối đa 10)
            if !warningEntries.isEmpty {
                lines.append("  ⚠️ Cảnh báo (\(warningEntries.count)):")
                for entry in warningEntries.suffix(10) {
                    let time = dateFormatter.string(from: entry.date)
                    lines.append("  🟡 [\(time)] \(entry.message)")
                }
            }
            lines.append("")
        }

        // === LOG GẦN NHẤT (giới hạn theo maxEntries) ===
        let recentCount = min(entries.count, maxEntries)
        lines.append("📋 LOG GẦN NHẤT (\(recentCount) dòng):")
        for entry in entries.suffix(recentCount) {
            let time = dateFormatter.string(from: entry.date)
            // Giới hạn độ dài message cho log thường (không phải error)
            let msg: String
            if entry.isImportant {
                // Error/Fault: hiển thị đầy đủ
                msg = entry.message
            } else {
                // Log thường: giới hạn 200 ký tự
                msg = entry.message.count > 200 ? String(entry.message.prefix(200)) + "..." : entry.message
            }
            lines.append("\(entry.levelEmoji) [\(time)] \(msg)")
        }

        return lines.joined(separator: "\n")
    }

    nonisolated private static func categoryIcon(_ category: String) -> String {
        switch category {
        case "Input": return "⌨️"
        case "Sync": return "🔄"
        case "UI": return "🖼️"
        case "Error": return "❌"
        case "Startup": return "🚀"
        case "Macro": return "📝"
        case "VNInput": return "🇻🇳"
        default: return "📌"
        }
    }

    nonisolated private static func buildNoLogsMessage() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
        return """
        📭 Không tìm thấy nhật ký PHTV gần đây.

        ℹ️ Điều này có thể do:
        • Ứng dụng mới khởi động
        • Chưa có hoạt động nào được ghi nhận

        📱 Thông tin ứng dụng:
        • Phiên bản: \(version)
        • macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)

        💡 Mẹo: Thử tái tạo lỗi rồi bấm "Làm mới" để lấy log mới.
        """
    }

    /// Tạo báo lỗi với logs đã được fetch sẵn (không block main thread)
    private func generateBugReportWithLogs(_ logs: String) -> String {
        var report = """
        # Báo lỗi PHTV

        ## 📋 Tiêu đề
        \(bugTitle.isEmpty ? "(Chưa nhập)" : bugTitle)

        ## 🧭 Phân loại
        - **Mức độ:** \(bugSeverity.badge) \(bugSeverity.displayName)
        - **Khu vực:** \(bugArea.displayName)
        \(contactEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "- **Liên hệ:** \(contactEmail)")

        ## 📝 Mô tả chi tiết
        \(bugDescription.isEmpty ? "(Chưa nhập)" : bugDescription)

        ## ✅ Bước tái hiện
        \(stepsToReproduce.isEmpty ? "(Chưa nhập)" : stepsToReproduce)

        ## 🎯 Kết quả mong muốn
        \(expectedResult.isEmpty ? "(Chưa nhập)" : expectedResult)

        ## ❗️Kết quả thực tế
        \(actualResult.isEmpty ? "(Chưa nhập)" : actualResult)

        """

        if appState.includeSystemInfo {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
            let macOS = ProcessInfo.processInfo.operatingSystemVersionString

            report += """
            ## 💻 Thông tin hệ thống
            - **Phiên bản PHTV:** \(version) (build \(build))
            - **macOS:** \(macOS)
            - **Chip:** \(getChipInfo())
            - **Bàn phím:** \(getCurrentKeyboardLayout())

            ## ⚙️ Cài đặt hiện tại
            - **Chế độ:** \(appState.isEnabled ? "🇻🇳 Tiếng Việt" : "🇬🇧 English")
            - **Kiểu gõ:** \(appState.inputMethod.rawValue)
            - **Bảng mã:** \(appState.codeTable.rawValue)
            - **Kiểm tra chính tả:** \(appState.checkSpelling ? "✅" : "❌")
            - **Gõ tắt (Macro):** \(appState.useMacro ? "✅" : "❌")
            - **Macro in English mode:** \(appState.useMacroInEnglishMode ? "✅" : "❌")
            - **Smart switch:** \(appState.useSmartSwitchKey ? "✅" : "❌")
            - **Modern orthography:** \(appState.useModernOrthography ? "✅" : "❌")
            - **Quick Telex:** \(appState.quickTelex ? "✅" : "❌")
            - **Phụ âm Z, F, W, J:** \(appState.allowConsonantZFWJ ? "✅" : "❌")
            - **Quick Start Consonant:** \(appState.quickStartConsonant ? "✅" : "❌")
            - **Quick End Consonant:** \(appState.quickEndConsonant ? "✅" : "❌")
            - **Beep on mode switch:** \(appState.beepOnModeSwitch ? "✅" : "❌")
            - **Vietnamese menubar icon:** \(appState.useVietnameseMenubarIcon ? "✅" : "❌")
            - **Show icon on Dock:** \(appState.showIconOnDock ? "✅" : "❌")

            ## 🔐 Quyền & Trạng thái
            - **Accessibility Permission:** \(appState.hasAccessibilityPermission ? "✅ Granted" : "❌ Denied")
            - **Event Tap:** \(checkEventTapStatus())
            - **Binary Architecture:** \(PHTVManager.getBinaryArchitectures())
            - **Binary Integrity:** \(PHTVManager.checkBinaryIntegrity() ? "✅ Intact" : "⚠️ Modified (CleanMyMac?)")
            - **Front App:** \(getFrontAppInfo())
            - **Excluded Apps:** \(appState.excludedApps.isEmpty ? "Không có" : "\(appState.excludedApps.count) app(s)")
            \(getExcludedAppsDetails())

            ## 🔧 Advanced Settings
            - **Layout Compat:** \(appState.performLayoutCompat ? "✅" : "❌")
            - **Safe Mode:** \(appState.safeMode ? "✅" : "❌")
            - **Send key step by step:** \(appState.sendKeyStepByStep ? "✅" : "❌")
            - **Auto restore English word:** \(appState.autoRestoreEnglishWord ? "✅" : "❌")
            - **Auto restore mode:** \(appState.autoRestoreEnglishWordMode.reportLabel)
            - **Restore on Escape:** \(appState.restoreOnEscape ? "✅" : "❌")
            - **Pause key enabled:** \(appState.pauseKeyEnabled ? "✅" : "❌")

            ## 📊 Hiệu năng
            \(getPerformanceInfo())

            ## 🌐 Browser & App Detection
            \(getBrowserDetectionInfo())

            """

        }

        // Thêm crash logs nếu có
        let crashLogs = getRecentCrashLogs()
        if !crashLogs.isEmpty {
            report += """
            ## 💥 Crash Logs gần đây
            ```
            \(crashLogs)
            ```

            """
        }

        if appState.includeLogs {
            // File logs từ PHTVLogger
            let fileLogs = PHTVLogger.shared.getFileLogs()
            if !fileLogs.isEmpty {
                report += """
                ## 📄 File Logs (PHTVLogger)
                ```
                \(String(fileLogs.suffix(2000)))
                ```

                """
            }

            // OSLog
            if !logs.isEmpty {
                report += """
                ## 📊 System Logs (OSLog)
                ```
                \(logs)
                ```
                """
            }
        }

        return report
    }

    private func copyBugReportToClipboardAsync() async {
        guard !isSending else { return }
        isSending = true

        // Lấy FULL logs cho clipboard (đầy đủ nhất)
        let logs: String
        if appState.includeLogs {
            logs = await Self.fetchLogsInBackground(maxEntries: 120)
            logBuffer = logs
        } else {
            logs = ""
        }

        let report = generateBugReportWithLogs(logs)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)

        isSending = false
        showCopiedAlert = true
    }

    private func openGitHubIssueAsync() async {
        guard !isSending else { return }
        isSending = true

        // Lấy log quan trọng
        let importantLogs: String
        if appState.includeLogs {
            importantLogs = await Self.fetchImportantLogsInBackground()
        } else {
            importantLogs = ""
        }

        // Tạo body cho GitHub URL
        let body = generateCompactReport(withLogs: importantLogs)

        // Encode URL
        let title = bugTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlString = "https://github.com/phamhungtien/PHTV/issues/new?title=\(title)&body=\(encodedBody)"

        if let url = URL(string: urlString) {
            openExternalURL(url)
        }

        isSending = false
    }

    /// Lấy log quan trọng - ƯU TIÊN LỖI trước, sau đó mới đến cảnh báo
    nonisolated private static func fetchImportantLogsOnly() -> String {
        var errors: [(time: String, message: String)] = []
        var warnings: [(time: String, message: String)] = []

        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(date: Date().addingTimeInterval(-30 * 60))
            let entries = try store.getEntries(at: position)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss"

            let skipPatterns = ["HALC_Proxy", "IOWorkLoop", "AddInstanceForFactory", "Reporter disconnected"]

            for entry in entries {
                if let logEntry = entry as? OSLogEntryLog {
                    let message = logEntry.composedMessage
                    guard !message.isEmpty else { continue }
                    if skipPatterns.contains(where: { message.contains($0) }) { continue }

                    let time = dateFormatter.string(from: logEntry.date)
                    // Giới hạn 120 ký tự cho URL
                    let truncatedMsg = message.count > 120 ? String(message.prefix(120)) + "..." : message

                    if logEntry.level == .error || logEntry.level == .fault {
                        errors.append((time, truncatedMsg))
                    } else if logEntry.level == .notice {
                        warnings.append((time, truncatedMsg))
                    }
                }
            }
        } catch {}

        // Tổng tối đa 20 chỗ, ưu tiên lỗi trước
        let maxTotal = 20
        var result: [String] = []

        // Lấy tất cả lỗi (tối đa 20)
        for (time, msg) in errors.suffix(maxTotal) {
            result.append("🔴 [\(time)] \(msg)")
        }

        // Thêm cảnh báo nếu còn chỗ
        let remainingSlots = maxTotal - result.count
        if remainingSlots > 0 {
            for (time, msg) in warnings.suffix(remainingSlots) {
                result.append("🟡 [\(time)] \(msg)")
            }
        }

        return result.joined(separator: "\n")
    }

    nonisolated private static func fetchImportantLogsInBackground() async -> String {
        fetchImportantLogsOnly()
    }

    /// Tạo báo lỗi ngắn gọn để gửi trực tiếp qua URL (không cần paste)
    private func generateCompactReport(withLogs logs: String = "") -> String {
        var report = ""

        // Mô tả
        if !bugDescription.isEmpty {
            report += "## 📝 Mô tả\n\(bugDescription)\n\n"
        }

        report += "## 🧭 Phân loại\n"
        report += "- **Mức độ:** \(bugSeverity.badge) \(bugSeverity.displayName)\n"
        report += "- **Khu vực:** \(bugArea.displayName)\n"
        if !contactEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            report += "- **Liên hệ:** \(contactEmail)\n"
        }
        report += "\n"

        if !stepsToReproduce.isEmpty {
            report += "## ✅ Bước tái hiện\n\(stepsToReproduce)\n\n"
        }
        if !expectedResult.isEmpty {
            report += "## 🎯 Kết quả mong muốn\n\(expectedResult)\n\n"
        }
        if !actualResult.isEmpty {
            report += "## ❗️Kết quả thực tế\n\(actualResult)\n\n"
        }

        // Thông tin hệ thống (rút gọn nhưng đầy đủ)
        if appState.includeSystemInfo {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
            let macOS = ProcessInfo.processInfo.operatingSystemVersionString
            let chip = getChipInfo()

            report += "## 💻 Hệ thống\n"
            report += "- **PHTV:** \(version) (\(build))\n"
            report += "- **macOS:** \(macOS)\n"
            report += "- **Chip:** \(chip)\n"
            report += "- **Chế độ:** \(appState.isEnabled ? "🇻🇳 Tiếng Việt" : "🇬🇧 English")\n"
            report += "- **Kiểu gõ:** \(appState.inputMethod.rawValue)\n"
            report += "- **Bảng mã:** \(appState.codeTable.rawValue)\n"

            // Thêm thông tin permission nếu không có quyền (quan trọng để debug)
            if !appState.hasAccessibilityPermission {
                report += "- ⚠️ **Accessibility:** ❌ Denied\n"
            }

            report += "\n"

            // Thêm các settings bất thường (khác default)
            var unusualSettings: [String] = []
            if !appState.useModernOrthography { unusualSettings.append("Old orthography") }
            if appState.quickTelex { unusualSettings.append("Quick Telex") }
            if appState.sendKeyStepByStep { unusualSettings.append("Send key step-by-step") }
            if !appState.excludedApps.isEmpty { unusualSettings.append("\(appState.excludedApps.count) excluded apps") }

            if !unusualSettings.isEmpty {
                report += "**⚙️ Settings:** " + unusualSettings.joined(separator: ", ") + "\n\n"
            }
        }

        // Log lỗi và cảnh báo quan trọng (rút gọn cho URL)
        if appState.includeLogs && !logs.isEmpty {
            report += "## ⚠️ Lỗi và cảnh báo gần đây\n```\n\(logs)\n```\n\n"
        }

        // Thêm crash logs nếu có (rút gọn cho URL)
        let crashLogs = getRecentCrashLogs()
        if !crashLogs.isEmpty {
            // Chỉ lấy phần đầu crash log cho URL
            let shortCrashLogs = String(crashLogs.prefix(500))
            report += "## 💥 Crash Logs\n\(shortCrashLogs)\n"
        }

        return report
    }

    private func sendEmailReportAsync() async {
        guard !isSending else { return }
        isSending = true

        // Lấy FULL logs cho email (không giới hạn như GitHub)
        let fullLogs: String
        if appState.includeLogs {
            fullLogs = await Self.fetchLogsInBackground(maxEntries: 120)
        } else {
            fullLogs = ""
        }

        // Tạo FULL report (đầy đủ nhất)
        let fullReport = generateBugReportWithLogs(fullLogs)

        // Copy full report vào clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullReport, forType: .string)

        // Tạo email với hướng dẫn paste
        let subject = "Báo lỗi PHTV: \(bugTitle)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = """
        [Báo cáo chi tiết đã được sao chép vào clipboard]

        Vui lòng dán (Cmd+V) báo cáo đầy đủ vào đây.

        ---
        Hoặc mô tả ngắn gọn:
        \(bugDescription.isEmpty ? "(Chưa nhập)" : bugDescription)
        """.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:phamhungtien.contact@gmail.com?subject=\(subject)&body=\(body)") {
            openExternalURL(url)
        }

        isSending = false
        showCopiedAlert = true // Thông báo đã copy
    }

    private func saveReportToFileAsync() async {
        guard !isSending else { return }
        isSending = true

        let logs: String
        if appState.includeLogs {
            logs = await Self.fetchLogsInBackground(maxEntries: 120)
        } else {
            logs = ""
        }

        let report = generateBugReportWithLogs(logs)
        reportDocument = BugReportDocument(text: report)
        showingSaveReportSheet = true

        isSending = false
    }

    @MainActor
    private func openExternalURL(_ url: URL) {
        openURL(url)
    }

    @MainActor
    private func applyLoadedLogs(_ logs: String) {
        logBuffer = logs
        isLoadingLogs = false
        hasLoadedLogsOnce = true
    }

    private func applyTemplateIfNeeded() {
        if bugDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bugDescription = "Mô tả ngắn gọn vấn đề và bối cảnh xảy ra."
        }
        if stepsToReproduce.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stepsToReproduce = "1. Mở...\n2. Thực hiện...\n3. Lỗi xuất hiện..."
        }
        if expectedResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            expectedResult = "Kết quả mong muốn là..."
        }
        if actualResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            actualResult = "Kết quả thực tế đang là..."
        }
    }

    private func clearForm() {
        bugTitle = ""
        bugDescription = ""
        stepsToReproduce = ""
        expectedResult = ""
        actualResult = ""
        contactEmail = ""
        bugSeverity = .normal
        bugArea = .typing
    }

    @ViewBuilder
    private func inputFieldBackground(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            PHTVRoundedRect(cornerRadius: cornerRadius)
                .fill(Color(NSColor.textBackgroundColor).opacity(0.6))
                .background(.regularMaterial)
                .clipShape(PHTVRoundedRect(cornerRadius: cornerRadius))
                .overlay(
                    PHTVRoundedRect(cornerRadius: cornerRadius)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
        } else {
            PHTVRoundedRect(cornerRadius: cornerRadius)
                .fill(Color(NSColor.textBackgroundColor))
                .overlay(
                    PHTVRoundedRect(cornerRadius: cornerRadius)
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                )
        }
    }

    private var logPreviewText: String {
        if logBuffer.isEmpty {
            return "Chưa có log để xem trước."
        }
        let lines = logBuffer.split(separator: "\n", omittingEmptySubsequences: false)
        let tail = lines.suffix(80)
        return tail.joined(separator: "\n")
    }
}

struct BugReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [phtvMarkdownContentType] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

#Preview {
    BugReportView()
        .environment(AppState.shared)
        .frame(width: 600, height: 800)
}
