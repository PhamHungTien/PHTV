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

// MARK: - Logger for PHTV
private let phtvLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.phamhungtien.phtv", category: "general")

struct BugReportView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    @State private var bugTitle: String = ""
    @State private var bugDescription: String = ""
    @State private var stepsToReproduce: String = ""
    @State private var expectedBehavior: String = ""
    @State private var actualBehavior: String = ""
    @State private var debugLogs: String = ""
    @State private var isLoadingLogs: Bool = false
    @State private var showCopiedAlert: Bool = false
    @State private var includeSystemInfo: Bool = true
    @State private var includeLogs: Bool = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Bug Information Form
                bugInfoSection

                // Debug Logs Section
                debugLogsSection

                // Actions
                actionsSection
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadDebugLogs()
        }
        .alert("Đã sao chép!", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nội dung báo lỗi đã được sao chép vào clipboard.")
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "ladybug.fill")
                .font(.system(size: 48))
                .foregroundStyle(themeManager.themeColor)

            Text("Báo lỗi")
                .font(.title.bold())

            Text("Giúp chúng tôi cải thiện PHTV bằng cách báo cáo lỗi bạn gặp phải")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 10)
    }

    // MARK: - Bug Info Section
    private var bugInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            SettingsCard(title: "Thông tin lỗi", icon: "exclamationmark.triangle.fill") {
                VStack(alignment: .leading, spacing: 16) {
                    // Bug Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tiêu đề lỗi")
                            .font(.headline)
                        TextField("Ví dụ: Không gõ được tiếng Việt trong Safari", text: $bugTitle)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mô tả chi tiết")
                            .font(.headline)
                        TextEditor(text: $bugDescription)
                            .frame(minHeight: 80)
                            .font(.body)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }

                    Divider()

                    // Steps to Reproduce
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Các bước để tái tạo lỗi")
                            .font(.headline)
                        TextEditor(text: $stepsToReproduce)
                            .frame(minHeight: 60)
                            .font(.body)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        Text("Ví dụ:\n1. Mở Safari\n2. Truy cập google.com\n3. Gõ tiếng Việt...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Expected vs Actual
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kết quả mong đợi")
                                .font(.headline)
                            TextEditor(text: $expectedBehavior)
                                .frame(minHeight: 50)
                                .font(.body)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kết quả thực tế")
                                .font(.headline)
                            TextEditor(text: $actualBehavior)
                                .frame(minHeight: 50)
                                .font(.body)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(4)
            }
        }
    }

    // MARK: - Debug Logs Section
    private var debugLogsSection: some View {
        SettingsCard(title: "Thông tin gỡ lỗi", icon: "doc.text.fill") {
            VStack(alignment: .leading, spacing: 12) {
                // Options
                Toggle("Bao gồm thông tin hệ thống", isOn: $includeSystemInfo)
                    .toggleStyle(.checkbox)

                Toggle("Bao gồm nhật ký debug", isOn: $includeLogs)
                    .toggleStyle(.checkbox)

                Divider()

                // System Info
                if includeSystemInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Thông tin hệ thống")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 4) {
                            systemInfoRow("Phiên bản PHTV", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A")
                            systemInfoRow("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A")
                            systemInfoRow("macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
                            systemInfoRow("Chip", value: getChipInfo())
                            systemInfoRow("Bàn phím", value: getCurrentKeyboardLayout())
                            systemInfoRow("Kiểu gõ", value: appState.inputMethod.rawValue)
                            systemInfoRow("Bảng mã", value: appState.codeTable.rawValue)
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Divider()
                }

                // Debug Logs
                if includeLogs {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Nhật ký debug")
                                .font(.headline)

                            Spacer()

                            Button {
                                loadDebugLogs()
                            } label: {
                                Label("Làm mới", systemImage: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .disabled(isLoadingLogs)
                        }

                        if isLoadingLogs {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Đang tải nhật ký...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: 180)
                            .background(Color(NSColor.textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            ScrollView {
                                Text(debugLogs.isEmpty ? "Không có nhật ký" : debugLogs)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 180)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Actions Section
    private var actionsSection: some View {
        SettingsCard(title: "Gửi báo lỗi", icon: "paperplane.fill") {
            VStack(spacing: 16) {
                Text("Chọn cách gửi báo lỗi phù hợp với bạn:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    // Copy to Clipboard
                    Button {
                        copyBugReportToClipboard()
                    } label: {
                        Label("Sao chép nội dung", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    // Open GitHub Issue
                    Button {
                        openGitHubIssue()
                    } label: {
                        Label("Tạo Issue GitHub", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.themeColor)
                    .controlSize(.large)

                    // Send Email
                    Button {
                        sendEmailReport()
                    } label: {
                        Label("Gửi Email", systemImage: "envelope")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(4)
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

    private func loadDebugLogs() {
        isLoadingLogs = true
        debugLogs = ""

        DispatchQueue.global(qos: .userInitiated).async {
            let logs = Self.fetchLogsSync()
            DispatchQueue.main.async {
                self.debugLogs = logs
                self.isLoadingLogs = false
            }
        }
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

    nonisolated private static func fetchLogsSync() -> String {
        var allLogEntries: [LogEntry] = []
        var stats = LogStats()

        // 1. Lấy log từ OSLogStore (unified logging)
        if #available(macOS 12.0, *) {
            do {
                let store = try OSLogStore(scope: .currentProcessIdentifier)
                let position = store.position(date: Date().addingTimeInterval(-30 * 60))
                let entries = try store.getEntries(at: position)

                for entry in entries {
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

        return buildFormattedOutput(entries: allLogEntries, stats: stats)
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

    nonisolated private static func buildFormattedOutput(entries: [LogEntry], stats: LogStats) -> String {
        var output = ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        let fullDateFormatter = DateFormatter()
        fullDateFormatter.dateFormat = "dd/MM HH:mm:ss"

        // === THỐNG KÊ TỔNG QUAN ===
        output += "📊 THỐNG KÊ TỔNG QUAN\n"
        output += "═══════════════════════════════════════\n"
        output += "📈 Tổng số log: \(stats.totalCount)\n"
        output += "⏱️ Thời gian: \(stats.duration)\n"

        if let first = stats.firstLogTime, let last = stats.lastLogTime {
            output += "📅 Từ \(fullDateFormatter.string(from: first)) đến \(fullDateFormatter.string(from: last))\n"
        }

        output += "\n"
        if stats.errorCount > 0 {
            output += "🔴 Lỗi: \(stats.errorCount)\n"
        }
        if stats.warningCount > 0 {
            output += "🟡 Cảnh báo: \(stats.warningCount)\n"
        }
        output += "🔵 Thông tin: \(stats.infoCount)\n"
        if stats.debugCount > 0 {
            output += "⚪ Debug: \(stats.debugCount)\n"
        }

        // Phân loại theo category
        if !stats.categoryCounts.isEmpty {
            output += "\n📁 PHÂN LOẠI THEO CHỨC NĂNG:\n"
            for (category, count) in stats.categoryCounts.sorted(by: { $0.value > $1.value }) {
                let icon = categoryIcon(category)
                let bar = String(repeating: "█", count: min(count, 20))
                output += "  \(icon) \(category.padding(toLength: 12, withPad: " ", startingAt: 0)) \(bar) (\(count))\n"
            }
        }

        // Lỗi gần nhất - QUAN TRỌNG
        if let lastError = stats.lastError, let errorTime = stats.lastErrorTime {
            output += "\n"
            output += "⚠️ ═══ LỖI GẦN NHẤT ═══\n"
            output += "🕐 Thời gian: \(fullDateFormatter.string(from: errorTime))\n"
            output += "📝 Nội dung:\n"
            // Wrap long error message
            let errorLines = lastError.components(separatedBy: .newlines)
            for line in errorLines.prefix(5) {
                output += "   \(line)\n"
            }
        }

        output += "\n"
        output += "═══════════════════════════════════════\n"
        output += "📜 CHI TIẾT NHẬT KÝ\n"
        output += "═══════════════════════════════════════\n\n"

        // === LỖI VÀ CẢNH BÁO TRƯỚC - HIỂN THỊ TẤT CẢ ===
        let importantEntries = entries.filter { $0.isImportant }
        if !importantEntries.isEmpty {
            output += "🚨 TẤT CẢ LỖI (\(importantEntries.count)):\n"
            output += "───────────────────────────────────────\n"
            for entry in importantEntries {
                let time = dateFormatter.string(from: entry.date)
                output += "\(entry.levelEmoji) [\(time)] \(entry.message)\n"
            }
            output += "\n"
        }

        // === LOG GẦN NHẤT - HIỂN THỊ NHIỀU HƠN ===
        let recentCount = min(entries.count, 100)
        output += "📋 LOG GẦN NHẤT (\(recentCount) dòng cuối):\n"
        output += "───────────────────────────────────────\n"
        for entry in entries.suffix(recentCount) {
            let time = dateFormatter.string(from: entry.date)
            let categoryPadded = "[\(entry.category)]".padding(toLength: 14, withPad: " ", startingAt: 0)
            output += "\(entry.levelEmoji) [\(time)] \(categoryPadded) \(entry.message)\n"
        }

        // Footer với thông tin cleanup
        output += "\n───────────────────────────────────────\n"
        output += "💾 Log tự động dọn dẹp: >2MB hoặc >24 giờ\n"

        return output
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

    private func generateBugReport() -> String {
        var report = """
        # Báo lỗi PHTV

        ## Tiêu đề
        \(bugTitle.isEmpty ? "(Chưa nhập)" : bugTitle)

        ## Mô tả
        \(bugDescription.isEmpty ? "(Chưa nhập)" : bugDescription)

        ## Các bước tái tạo
        \(stepsToReproduce.isEmpty ? "(Chưa nhập)" : stepsToReproduce)

        ## Kết quả mong đợi
        \(expectedBehavior.isEmpty ? "(Chưa nhập)" : expectedBehavior)

        ## Kết quả thực tế
        \(actualBehavior.isEmpty ? "(Chưa nhập)" : actualBehavior)

        """

        if includeSystemInfo {
            report += """

            ## Thông tin hệ thống
            - Phiên bản PHTV: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A")
            - Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A")
            - macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
            - Chip: \(getChipInfo())
            - Bàn phím: \(getCurrentKeyboardLayout())
            - Kiểu gõ: \(appState.inputMethod.rawValue)
            - Bảng mã: \(appState.codeTable.rawValue)

            """
        }

        if includeLogs {
            // Luôn lấy log mới nhất khi gửi báo lỗi
            let freshLogs = Self.fetchLogsSync()
            if !freshLogs.isEmpty {
                report += """

            ## Nhật ký Debug
            ```
            \(freshLogs)
            ```
            """
            }
        }

        return report
    }

    private func copyBugReportToClipboard() {
        // Cập nhật log mới nhất trước khi sao chép
        debugLogs = Self.fetchLogsSync()

        let report = generateBugReport()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        showCopiedAlert = true
    }

    private func openGitHubIssue() {
        // Cập nhật log mới nhất
        debugLogs = Self.fetchLogsSync()

        let title = bugTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = generateBugReport().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // GitHub has URL length limits, so we might need to truncate
        var urlString = "https://github.com/phamhungtien/PHTV/issues/new?title=\(title)&body="

        // Check URL length and truncate if needed
        let maxBodyLength = 8000 - urlString.count
        var truncatedBody = body
        if body.count > maxBodyLength {
            truncatedBody = String(body.prefix(maxBodyLength))
            truncatedBody += "...(nội dung bị cắt, vui lòng dán từ clipboard)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        }

        urlString += truncatedBody

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }

        // Also copy to clipboard in case URL is truncated
        let report = generateBugReport()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }

    private func sendEmailReport() {
        // Cập nhật log mới nhất
        debugLogs = Self.fetchLogsSync()

        let subject = "Báo lỗi PHTV: \(bugTitle)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = generateBugReport().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:hungtien10a7@gmail.com?subject=\(subject)&body=\(body)") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    BugReportView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
        .frame(width: 600, height: 800)
}
