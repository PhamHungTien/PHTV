//
//  BugReportCrashLogCollector.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

enum BugReportCrashLogCollector {
    enum Detail: Sendable {
        case compact
        case full

        var crashLimit: Int { self == .compact ? 1 : 3 }
        var frameLimit: Int { self == .compact ? 10 : 16 }
        var characterLimit: Int { self == .compact ? 2_600 : 12_000 }
    }

    static func recentCrashLogsInBackground(
        includeCrashLogs: Bool,
        detail: Detail = .full
    ) async -> String {
        guard includeCrashLogs else { return "" }

        return await Task.detached(priority: .utility) {
            recentCrashLogs(includeCrashLogs: true, detail: detail)
        }.value
    }

    static func recentCrashLogs(
        includeCrashLogs: Bool,
        detail: Detail = .full,
        now: Date = Date(),
        crashLogsPath: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports")
    ) -> String {
        guard includeCrashLogs else { return "" }

        let resourceKeys: Set<URLResourceKey> = [.creationDateKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: crashLogsPath,
            includingPropertiesForKeys: Array(resourceKeys),
            options: .skipsHiddenFiles
        ) else {
            return ""
        }

        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let phtvCrashes = files.compactMap { file -> (url: URL, date: Date)? in
            let name = file.lastPathComponent.lowercased()
            guard name.contains("phtv"), ["ips", "crash"].contains(file.pathExtension.lowercased()) else {
                return nil
            }

            let values = try? file.resourceValues(forKeys: resourceKeys)
            guard let date = values?.contentModificationDate ?? values?.creationDate,
                  date > sevenDaysAgo else {
                return nil
            }
            return (file, date)
        }.sorted { $0.date > $1.date }

        guard !phtvCrashes.isEmpty else { return "" }

        var sections = ["Tìm thấy \(phtvCrashes.count) crash log PHTV trong 7 ngày gần đây."]
        for (index, crash) in phtvCrashes.prefix(detail.crashLimit).enumerated() {
            guard let content = try? String(contentsOf: crash.url, encoding: .utf8) else {
                sections.append("Crash \(index + 1): \(crash.url.lastPathComponent)\nKhông thể đọc nội dung tệp.")
                continue
            }
            sections.append(
                formattedCrashReport(
                    content: content,
                    filename: crash.url.lastPathComponent,
                    detail: detail,
                    ordinal: index + 1
                )
            )
        }

        if phtvCrashes.count > detail.crashLimit {
            let remaining = phtvCrashes.count - detail.crashLimit
            sections.append("Còn \(remaining) crash log khác chưa hiển thị để giữ báo cáo gọn.")
        }

        sections.append(
            "Dữ liệu nhạy cảm như tên người dùng, đường dẫn home, UUID thiết bị, "
                + "thanh ghi và địa chỉ bộ nhớ đã được lược bỏ."
        )
        return limited(sections.joined(separator: "\n\n"), to: detail.characterLimit)
    }

    static func formattedCrashReport(
        content: String,
        filename: String,
        detail: Detail,
        ordinal: Int = 1
    ) -> String {
        if let modern = parseModernCrash(content) {
            return renderModernCrash(modern, filename: filename, detail: detail, ordinal: ordinal)
        }
        return renderLegacyCrash(content, filename: filename, detail: detail, ordinal: ordinal)
    }
}

// MARK: - Modern .ips JSON

private extension BugReportCrashLogCollector {
    typealias JSONDictionary = [String: Any]

    struct ModernCrash {
        let metadata: JSONDictionary
        let report: JSONDictionary
    }

    static func parseModernCrash(_ content: String) -> ModernCrash? {
        let lines = content.components(separatedBy: .newlines)
        var metadata: JSONDictionary = [:]
        var reportParseAttempts = 0

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("{") else { continue }

            if let dictionary = jsonDictionary(from: trimmed),
               dictionary["bug_type"] != nil || dictionary["app_name"] != nil {
                metadata = dictionary
                continue
            }

            guard reportParseAttempts < 3 else { break }
            reportParseAttempts += 1
            let candidate = lines[index...].joined(separator: "\n")
            if let report = jsonDictionary(from: candidate),
               report["threads"] != nil || report["exception"] != nil {
                return ModernCrash(metadata: metadata, report: report)
            }
        }

        return nil
    }

    static func jsonDictionary(from text: String) -> JSONDictionary? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? JSONDictionary else {
            return nil
        }
        return dictionary
    }

    static func renderModernCrash(
        _ crash: ModernCrash,
        filename: String,
        detail: Detail,
        ordinal: Int
    ) -> String {
        let metadata = crash.metadata
        let report = crash.report
        let bundle = report["bundleInfo"] as? JSONDictionary ?? [:]
        let os = report["osVersion"] as? JSONDictionary ?? [:]
        let exception = report["exception"] as? JSONDictionary ?? [:]
        let termination = report["termination"] as? JSONDictionary ?? [:]

        let version = string(metadata["app_version"])
            ?? string(bundle["CFBundleShortVersionString"])
        let build = string(metadata["build_version"])
            ?? string(bundle["CFBundleVersion"])
        let versionDescription = [version, build.map { "build \($0)" }]
            .compactMap { $0 }
            .joined(separator: ", ")
        let osDescription = string(metadata["os_version"])
            ?? joinedNonEmpty([string(os["train"]), string(os["build"])], separator: " ")

        var lines = ["Crash \(ordinal): \(sanitize(filename))"]
        appendFact("Thời điểm", value: string(metadata["timestamp"]) ?? string(report["captureTime"]), to: &lines)
        appendFact("PHTV", value: versionDescription.nilIfEmpty, to: &lines)
        appendFact("macOS", value: osDescription, to: &lines)
        appendFact(
            "Phần cứng",
            value: joinedNonEmpty(
                [string(report["modelCode"]), string(report["cpuType"])],
                separator: ", "
            ),
            to: &lines
        )
        appendFact(
            "Ngoại lệ",
            value: joinedNonEmpty(
                [string(exception["type"]), string(exception["signal"])],
                separator: " / "
            ),
            to: &lines
        )

        let terminationDescription = joinedNonEmpty(
            [string(termination["namespace"]), string(termination["code"]).map { "code \($0)" }, string(termination["indicator"])],
            separator: ", "
        )
        appendFact("Kết thúc", value: terminationDescription, to: &lines)

        let images = report["usedImages"] as? [JSONDictionary] ?? []
        let lastExceptionFrames = report["lastExceptionBacktrace"] as? [JSONDictionary] ?? []
        let threads = report["threads"] as? [JSONDictionary] ?? []
        let faultingIndex = integer(report["faultingThread"])
        let faultingThread = faultingIndex.flatMap { threads.indices.contains($0) ? threads[$0] : nil }

        if let faultingThread {
            let threadLabel = joinedNonEmpty(
                [faultingIndex.map { "#\($0)" }, string(faultingThread["name"]), string(faultingThread["queue"])],
                separator: " — "
            )
            appendFact("Luồng gây crash", value: threadLabel, to: &lines)
        }

        if !lastExceptionFrames.isEmpty {
            lines.append("Last exception backtrace:")
            lines.append(contentsOf: renderFrames(lastExceptionFrames, images: images, limit: detail.frameLimit))
        }

        if detail == .full,
           let faultingFrames = faultingThread?["frames"] as? [JSONDictionary],
           !faultingFrames.isEmpty {
            lines.append("Faulting thread backtrace:")
            lines.append(contentsOf: renderFrames(faultingFrames, images: images, limit: detail.frameLimit))
        } else if lastExceptionFrames.isEmpty,
                  let faultingFrames = faultingThread?["frames"] as? [JSONDictionary],
                  !faultingFrames.isEmpty {
            lines.append("Faulting thread backtrace:")
            lines.append(contentsOf: renderFrames(faultingFrames, images: images, limit: detail.frameLimit))
        }

        return sanitize(lines.joined(separator: "\n"))
    }

    static func renderFrames(
        _ frames: [JSONDictionary],
        images: [JSONDictionary],
        limit: Int
    ) -> [String] {
        frames.prefix(limit).enumerated().map { index, frame in
            let imageName = integer(frame["imageIndex"])
                .flatMap { images.indices.contains($0) ? string(images[$0]["name"]) : nil }
                ?? "Unknown image"
            let symbol = string(frame["symbol"]) ?? "<unknown symbol>"
            let source = joinedNonEmpty(
                [string(frame["sourceFile"]), string(frame["sourceLine"]).map { "line \($0)" }],
                separator: ": "
            )
            let sourceSuffix = source.map { " (\($0))" } ?? ""
            return "  #\(index) \(imageName) — \(symbol)\(sourceSuffix)"
        }
    }
}

// MARK: - Legacy translated crash reports

private extension BugReportCrashLogCollector {
    static func renderLegacyCrash(
        _ content: String,
        filename: String,
        detail: Detail,
        ordinal: Int
    ) -> String {
        let sourceLines = content.components(separatedBy: .newlines)
        let usefulPrefixes = [
            "Date/Time:", "Version:", "OS Version:", "Code Type:",
            "Triggered by Thread:", "Exception Type:", "Exception Codes:",
            "Termination Reason:"
        ]
        var lines = ["Crash \(ordinal): \(sanitize(filename))"]

        for prefix in usefulPrefixes {
            if let line = sourceLines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }) {
                lines.append(line.trimmingCharacters(in: .whitespaces))
            }
        }

        let stackHeaders = ["Last Exception Backtrace:", "Thread 0 Crashed:"]
        if let headerIndex = sourceLines.firstIndex(where: { line in
            stackHeaders.contains { line.trimmingCharacters(in: .whitespaces).hasPrefix($0) }
        }) {
            lines.append(sourceLines[headerIndex].trimmingCharacters(in: .whitespaces))
            for line in sourceLines.dropFirst(headerIndex + 1) {
                if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break }
                lines.append(line)
                if lines.count >= detail.frameLimit + usefulPrefixes.count + 2 { break }
            }
        } else {
            lines.append("Không tìm thấy stack trace trong định dạng crash report này.")
        }

        return sanitize(lines.joined(separator: "\n"))
    }
}

// MARK: - Formatting and privacy

private extension BugReportCrashLogCollector {
    static func appendFact(_ label: String, value: String?, to lines: inout [String]) {
        guard let value = value?.nilIfEmpty else { return }
        lines.append("- \(label): \(value)")
    }

    static func string(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        case let value as NSNumber:
            return value.stringValue
        default:
            return nil
        }
    }

    static func integer(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }

    static func joinedNonEmpty(_ values: [String?], separator: String) -> String? {
        let joined = values.compactMap { $0?.nilIfEmpty }.joined(separator: separator)
        return joined.nilIfEmpty
    }

    static func sanitize(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"/Users/[^/\s]+/"#,
            with: "~/",
            options: .regularExpression
        )
    }

    static func limited(_ text: String, to characterLimit: Int) -> String {
        guard text.count > characterLimit else { return text }
        return String(text.prefix(characterLimit))
            + "\n… Báo cáo crash đã được rút gọn; hãy lưu báo cáo ra tệp để xem bản đầy đủ."
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
