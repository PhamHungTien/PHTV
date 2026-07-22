//
//  BugReportLogCollector.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import OSLog

enum BugReportLogCollector {
    nonisolated static func fetchLogsInBackground(maxEntries: Int = 100) async -> String {
        autoreleasepool {
            fetchLogsSync(maxEntries: maxEntries)
        }
    }

    nonisolated static func fetchImportantLogsInBackground() async -> String {
        fetchImportantLogsOnly()
    }

    private struct LogEntry {
        let date: Date
        let level: OSLogEntryLog.Level
        let category: String
        let message: String

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

        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(date: Date().addingTimeInterval(-15 * 60))
            let entries = try store.getEntries(at: position)

            var regularLogCount = 0
            let maxRegularLogs = maxEntries
            let maxTotalLogs = maxEntries * 2

            for entry in entries {
                guard let logEntry = entry as? OSLogEntryLog else { continue }
                var message = logEntry.composedMessage
                guard !message.isEmpty else { continue }

                let isErrorOrWarning = logEntry.level == .error || logEntry.level == .fault || logEntry.level == .notice

                if shouldFilterOut(message: message, subsystem: logEntry.subsystem, level: logEntry.level) {
                    continue
                }

                if !isErrorOrWarning {
                    if regularLogCount >= maxRegularLogs {
                        continue
                    }
                    regularLogCount += 1
                }

                if message.count > 400 {
                    message = String(message.prefix(400)) + "..."
                }

                allLogEntries.append(
                    LogEntry(
                        date: logEntry.date,
                        level: logEntry.level,
                        category: detectCategory(from: message),
                        message: message
                    )
                )

                if allLogEntries.count >= maxTotalLogs {
                    break
                }
            }
        } catch {
            // OSLogStore can fail in some sandbox/debug contexts. The caller still gets a useful explanation.
        }

        allLogEntries.sort { $0.date < $1.date }

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

    nonisolated private static func shouldFilterOut(message: String, subsystem: String, level: OSLogEntryLog.Level) -> Bool {
        if level == .error || level == .fault {
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

        if subsystem.contains("phtv") || subsystem.contains("PHTV") {
            return false
        }

        let keepPatterns = [
            "[PHTV", "PHTV]", "[phtv",
            "[Permission]", "[Accessibility]",
            "[SettingsView]", "[InputMethod]",
            "[EventTap]", "[HotkeyHealth]",
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
        var lines: [String] = []
        lines.reserveCapacity(maxEntries + 30)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        let fullDateFormatter = DateFormatter()
        fullDateFormatter.dateFormat = "dd/MM HH:mm:ss"

        lines.append("📊 THỐNG KÊ: \(stats.totalCount) log | \(stats.duration)")

        if stats.errorCount > 0 {
            lines.append("🔴 Lỗi: \(stats.errorCount) | 🟡 Cảnh báo: \(stats.warningCount)")
        }

        if let lastError = stats.lastError, let errorTime = stats.lastErrorTime {
            lines.append("")
            lines.append("⚠️ LỖI GẦN NHẤT [\(fullDateFormatter.string(from: errorTime))]:")
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

        let errorEntries = entries.filter { $0.level == .error || $0.level == .fault }
        let warningEntries = entries.filter { $0.level == .notice }

        if !errorEntries.isEmpty || !warningEntries.isEmpty {
            lines.append("🚨 LỖI VÀ CẢNH BÁO:")

            if !errorEntries.isEmpty {
                lines.append("  📛 Lỗi (\(errorEntries.count)):")
                for entry in errorEntries.suffix(20) {
                    let time = dateFormatter.string(from: entry.date)
                    lines.append("  🔴 [\(time)] \(entry.message)")
                }
            }

            if !warningEntries.isEmpty {
                lines.append("  ⚠️ Cảnh báo (\(warningEntries.count)):")
                for entry in warningEntries.suffix(10) {
                    let time = dateFormatter.string(from: entry.date)
                    lines.append("  🟡 [\(time)] \(entry.message)")
                }
            }
            lines.append("")
        }

        let recentCount = min(entries.count, maxEntries)
        lines.append("📋 LOG GẦN NHẤT (\(recentCount) dòng):")
        for entry in entries.suffix(recentCount) {
            let time = dateFormatter.string(from: entry.date)
            let msg = entry.isImportant
                ? entry.message
                : (entry.message.count > 200 ? String(entry.message.prefix(200)) + "..." : entry.message)
            lines.append("\(entry.levelEmoji) [\(time)] \(msg)")
        }

        return lines.joined(separator: "\n")
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
                guard let logEntry = entry as? OSLogEntryLog else { continue }
                let message = logEntry.composedMessage
                guard !message.isEmpty else { continue }
                if skipPatterns.contains(where: { message.contains($0) }) { continue }

                let time = dateFormatter.string(from: logEntry.date)
                let truncatedMsg = message.count > 120 ? String(message.prefix(120)) + "..." : message

                if logEntry.level == .error || logEntry.level == .fault {
                    errors.append((time, truncatedMsg))
                } else if logEntry.level == .notice {
                    warnings.append((time, truncatedMsg))
                }
            }
        } catch {}

        let maxTotal = 20
        var result: [String] = []

        for (time, msg) in errors.suffix(maxTotal) {
            result.append("🔴 [\(time)] \(msg)")
        }

        let remainingSlots = maxTotal - result.count
        if remainingSlots > 0 {
            for (time, msg) in warnings.suffix(remainingSlots) {
                result.append("🟡 [\(time)] \(msg)")
            }
        }

        return result.joined(separator: "\n")
    }
}
