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

// MARK: - Logger for PHTV
private let phtvLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.phamhungtien.phtv", category: "general")

struct BugReportView: View {
    @EnvironmentObject var appState: AppState

    @State private var bugTitle: String = ""
    @State private var bugDescription: String = ""
    @State private var debugLogs: String = ""
    @State private var isLoadingLogs: Bool = false
    @State private var showCopiedAlert: Bool = false
    @State private var includeSystemInfo: Bool = true
    @State private var includeLogs: Bool = true
    @State private var cachedLogs: String = ""
    @State private var isSending: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Bug Information Form
                bugInfoSection

                // Debug Options & Info
                debugOptionsSection

                // Actions
                actionsSection

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .settingsBackground()
        .task {
            if cachedLogs.isEmpty {
                await loadDebugLogsAsync()
            }
        }
        .alert("Đã sao chép!", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nội dung báo lỗi đã được sao chép vào clipboard.")
        }
    }

    // MARK: - Bug Info Section
    private var bugInfoSection: some View {
        SettingsCard(title: "Báo lỗi", icon: "ladybug.fill") {
            VStack(alignment: .leading, spacing: 12) {
                // Bug Title
                TextField("Tiêu đề lỗi (VD: Không gõ được tiếng Việt trong Safari)", text: $bugTitle)
                    .textFieldStyle(.roundedBorder)

                // Description
                TextEditor(text: $bugDescription)
                    .frame(minHeight: 100)
                    .font(.body)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if bugDescription.isEmpty {
                            Text("Mô tả chi tiết lỗi và các bước để tái tạo...")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
    }

    // MARK: - Debug Options Section
    private var debugOptionsSection: some View {
        SettingsCard(title: "Thông tin gỡ lỗi", icon: "doc.text.fill") {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "cpu.fill",
                    iconColor: .accentColor,
                    title: "Thông tin hệ thống",
                    subtitle: "Phiên bản PHTV, macOS, chip, bàn phím",
                    isOn: $includeSystemInfo
                )

                SettingsDivider()

                SettingsToggleRow(
                    icon: "doc.text.fill",
                    iconColor: .accentColor,
                    title: "Nhật ký debug",
                    subtitle: "Log hoạt động gần đây của ứng dụng",
                    isOn: $includeLogs
                )
            }
        }
    }

    // MARK: - Actions Section
    private var actionsSection: some View {
        SettingsCard(title: "Gửi báo lỗi", icon: "paperplane.fill") {
            HStack(spacing: 10) {
                // Copy to Clipboard
                Button {
                    Task { await copyBugReportToClipboardAsync() }
                } label: {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(maxWidth: .infinity, minHeight: 32)
                    } else {
                        Label("Sao chép", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                }
                .adaptiveBorderedButtonStyle()
                .disabled(isSending)

                // Open GitHub Issue
                Button {
                    Task { await openGitHubIssueAsync() }
                } label: {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(maxWidth: .infinity, minHeight: 32)
                    } else {
                        Label("GitHub Issue", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                }
                .adaptiveProminentButtonStyle()
                .tint(.accentColor)
                .disabled(isSending)

                // Send Email
                Button {
                    Task { await sendEmailReportAsync() }
                } label: {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(maxWidth: .infinity, minHeight: 32)
                    } else {
                        Label("Email", systemImage: "envelope")
                            .frame(maxWidth: .infinity)
                    }
                }
                .adaptiveBorderedButtonStyle()
                .disabled(isSending)
            }
            .padding(.vertical, 4)
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
        // Check if event tap is running
        let isRunning = AXIsProcessTrusted()
        return isRunning ? "✅ Running" : "❌ Not running"
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

    private func getRecentCrashLogs() -> String {
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

        Task.detached(priority: .userInitiated) {
            let logs = Self.fetchLogsSync(maxEntries: 50) // Giới hạn số log
            await MainActor.run {
                self.debugLogs = logs
                self.cachedLogs = logs
                self.isLoadingLogs = false
            }
        }
    }

    private func loadDebugLogsAsync() async {
        guard !isLoadingLogs else { return }
        isLoadingLogs = true

        let logs = await Task.detached(priority: .userInitiated) {
            Self.fetchLogsSync(maxEntries: 50) // Giới hạn số log
        }.value

        debugLogs = logs
        cachedLogs = logs
        isLoadingLogs = false
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
            level == .error || level == .fault
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

    nonisolated private static func fetchLogsSync(maxEntries: Int = 50) -> String {
        var allLogEntries: [LogEntry] = []
        var stats = LogStats()

        // 1. Lấy log từ OSLogStore (unified logging)
        if #available(macOS 12.0, *) {
            do {
                let store = try OSLogStore(scope: .currentProcessIdentifier)
                // Giảm thời gian từ 30 phút xuống 10 phút để giảm số log cần xử lý
                let position = store.position(date: Date().addingTimeInterval(-10 * 60))
                let entries = try store.getEntries(at: position)

                var count = 0
                for entry in entries {
                    // Dừng sớm nếu đã đủ số log cần thiết (nhưng vẫn giữ lỗi)
                    if count >= maxEntries * 3 { break }

                    if let logEntry = entry as? OSLogEntryLog {
                        let message = logEntry.composedMessage
                        guard !message.isEmpty else { continue }

                        // Lọc bỏ log hệ thống không liên quan
                        if shouldFilterOut(message: message, subsystem: logEntry.subsystem, level: logEntry.level) {
                            continue
                        }

                        let category = detectCategory(from: message)
                        let entry = LogEntry(
                            date: logEntry.date,
                            level: logEntry.level,
                            category: category,
                            message: message
                        )
                        allLogEntries.append(entry)
                        count += 1
                    }
                }
            } catch {
                // Ignore OSLogStore errors, fallback to file logs
            }
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

    nonisolated private static func buildFormattedOutput(entries: [LogEntry], stats: LogStats, maxEntries: Int = 50) -> String {
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
            // Chỉ lấy 2 dòng đầu của lỗi
            let errorLines = lastError.components(separatedBy: .newlines)
            for line in errorLines.prefix(2) {
                lines.append("  \(line)")
            }
        }

        lines.append("")
        lines.append("───────────────────────────────────────")

        // === LỖI TRƯỚC (giới hạn 10) ===
        let importantEntries = entries.filter { $0.isImportant }
        if !importantEntries.isEmpty {
            lines.append("🚨 LỖI (\(min(importantEntries.count, 10))/\(importantEntries.count)):")
            for entry in importantEntries.suffix(10) {
                let time = dateFormatter.string(from: entry.date)
                // Giới hạn độ dài message
                let msg = entry.message.count > 100 ? String(entry.message.prefix(100)) + "..." : entry.message
                lines.append("\(entry.levelEmoji) [\(time)] \(msg)")
            }
            lines.append("")
        }

        // === LOG GẦN NHẤT (giới hạn theo maxEntries) ===
        let recentCount = min(entries.count, maxEntries)
        lines.append("📋 LOG GẦN NHẤT (\(recentCount) dòng):")
        for entry in entries.suffix(recentCount) {
            let time = dateFormatter.string(from: entry.date)
            // Giới hạn độ dài message để giảm kích thước
            let msg = entry.message.count > 80 ? String(entry.message.prefix(80)) + "..." : entry.message
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

        ## 📝 Mô tả chi tiết
        \(bugDescription.isEmpty ? "(Chưa nhập)" : bugDescription)

        """

        if includeSystemInfo {
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
            - **Smart switch:** \(appState.useSmartSwitchKey ? "✅" : "❌")
            - **Modern orthography:** \(appState.useModernOrthography ? "✅" : "❌")
            - **Quick Telex:** \(appState.quickTelex ? "✅" : "❌")
            - **Beep on mode switch:** \(appState.beepOnModeSwitch ? "✅" : "❌")

            ## 🔐 Quyền & Trạng thái
            - **Accessibility Permission:** \(appState.hasAccessibilityPermission ? "✅ Granted" : "❌ Denied")
            - **Event Tap:** \(checkEventTapStatus())
            - **Front App:** \(getFrontAppInfo())
            - **Excluded Apps:** \(appState.excludedApps.isEmpty ? "Không có" : "\(appState.excludedApps.count) app(s)")
            \(getExcludedAppsDetails())

            ## 🔧 Advanced Settings
            - **Fix Chromium Browser:** \(appState.fixChromiumBrowser ? "✅" : "❌")
            - **Layout Compat:** \(appState.performLayoutCompat ? "✅" : "❌")
            - **Safe Mode:** \(appState.safeMode ? "✅" : "❌")
            - **Send key step by step:** \(appState.sendKeyStepByStep ? "✅" : "❌")
            - **Restore on invalid word:** \(appState.restoreOnInvalidWord ? "✅" : "❌")
            - **Auto restore English word:** \(appState.autoRestoreEnglishWord ? "✅" : "❌")

            ## 📊 Hiệu năng
            \(getPerformanceInfo())

            """

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
        }

        if includeLogs {
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

        // Lấy log trên background thread
        let logs = await Task.detached(priority: .utility) {
            Self.fetchLogsSync(maxEntries: 50)
        }.value

        debugLogs = logs
        cachedLogs = logs

        let report = generateBugReportWithLogs(logs)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)

        isSending = false
        showCopiedAlert = true
    }

    private func openGitHubIssueAsync() async {
        guard !isSending else { return }
        isSending = true

        // Lấy log quan trọng (chỉ errors) trên background
        let importantLogs = await Task.detached(priority: .utility) {
            Self.fetchImportantLogsOnly()
        }.value

        // Tạo body ngắn gọn cho GitHub
        let body = generateCompactReport(withLogs: importantLogs)

        // Encode URL
        let title = bugTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlString = "https://github.com/phamhungtien/PHTV/issues/new?title=\(title)&body=\(encodedBody)"

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }

        isSending = false
    }

    /// Lấy chỉ các log quan trọng (errors, faults) - rất nhanh
    nonisolated private static func fetchImportantLogsOnly() -> String {
        var errorMessages: [String] = []

        if #available(macOS 12.0, *) {
            do {
                let store = try OSLogStore(scope: .currentProcessIdentifier)
                let position = store.position(date: Date().addingTimeInterval(-5 * 60)) // 5 phút gần nhất
                let entries = try store.getEntries(at: position)

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "HH:mm:ss"

                for entry in entries {
                    if errorMessages.count >= 5 { break } // Tối đa 5 lỗi

                    if let logEntry = entry as? OSLogEntryLog {
                        // Chỉ lấy ERROR và FAULT
                        guard logEntry.level == .error || logEntry.level == .fault else { continue }

                        let message = logEntry.composedMessage
                        guard !message.isEmpty else { continue }

                        // Bỏ qua system errors không liên quan
                        let skipPatterns = ["HALC_Proxy", "IOWorkLoop", "AddInstanceForFactory", "Reporter disconnected"]
                        if skipPatterns.contains(where: { message.contains($0) }) { continue }

                        let time = dateFormatter.string(from: logEntry.date)
                        let shortMsg = message.count > 60 ? String(message.prefix(60)) + "..." : message
                        errorMessages.append("[\(time)] \(shortMsg)")
                    }
                }
            } catch {
                // Ignore
            }
        }

        return errorMessages.isEmpty ? "" : errorMessages.joined(separator: "\n")
    }

    /// Tạo báo lỗi ngắn gọn để gửi trực tiếp qua URL (không cần paste)
    private func generateCompactReport(withLogs logs: String = "") -> String {
        var report = ""

        // Mô tả
        if !bugDescription.isEmpty {
            report += "## 📝 Mô tả\n\(bugDescription)\n\n"
        }

        // Thông tin hệ thống (rút gọn nhưng đầy đủ)
        if includeSystemInfo {
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
            if !appState.checkSpelling { unusualSettings.append("No spell check") }
            if !appState.useModernOrthography { unusualSettings.append("Old orthography") }
            if appState.quickTelex { unusualSettings.append("Quick Telex") }
            if appState.fixChromiumBrowser { unusualSettings.append("Chromium fix") }
            if appState.sendKeyStepByStep { unusualSettings.append("Send key step-by-step") }
            if !appState.excludedApps.isEmpty { unusualSettings.append("\(appState.excludedApps.count) excluded apps") }

            if !unusualSettings.isEmpty {
                report += "**⚙️ Settings:** " + unusualSettings.joined(separator: ", ") + "\n\n"
            }
        }

        // Log lỗi quan trọng
        if includeLogs && !logs.isEmpty {
            report += "## 🔴 Lỗi gần đây\n```\n\(logs)\n```\n\n"
        }

        // Thêm crash logs nếu có (rất quan trọng)
        let crashLogs = getRecentCrashLogs()
        if !crashLogs.isEmpty {
            report += "## 💥 Crash Logs\n\(crashLogs)\n"
        }

        return report
    }

    private func sendEmailReportAsync() async {
        guard !isSending else { return }
        isSending = true

        // Lấy log quan trọng
        let importantLogs = await Task.detached(priority: .utility) {
            Self.fetchImportantLogsOnly()
        }.value

        let body = generateCompactReport(withLogs: importantLogs)

        let subject = "Báo lỗi PHTV: \(bugTitle)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:hungtien10a7@gmail.com?subject=\(subject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }

        isSending = false
    }
}

#Preview {
    BugReportView()
        .environmentObject(AppState.shared)
        .frame(width: 600, height: 800)
}
