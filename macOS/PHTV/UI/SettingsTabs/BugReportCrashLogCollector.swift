//
//  BugReportCrashLogCollector.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

enum BugReportCrashLogCollector {
    static func recentCrashLogs(includeCrashLogs: Bool) -> String {
        guard includeCrashLogs else { return "" }

        let crashLogsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports")

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: crashLogsPath,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return ""
        }

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

        if let firstCrash = phtvCrashes.first,
           let content = try? String(contentsOf: firstCrash, encoding: .utf8) {
            crashReport += "**File:** \(firstCrash.lastPathComponent)\n\n"

            let lines = content.components(separatedBy: .newlines)

            if let crashReasonLine = lines.first(where: { $0.contains("Exception Type:") || $0.contains("Termination Reason:") }) {
                crashReport += "\(crashReasonLine)\n"
            }

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
                    if threadLines.count > 15 { break }
                }
            }

            if !threadLines.isEmpty {
                crashReport += "\n```\n"
                crashReport += threadLines.joined(separator: "\n")
                crashReport += "\n```\n"
            }
        }

        if phtvCrashes.count > 1 {
            crashReport += "\n**Các crash khác:**\n"
            for crash in phtvCrashes.dropFirst().prefix(3) {
                crashReport += "- \(crash.lastPathComponent)\n"
            }
        }

        return crashReport
    }
}
