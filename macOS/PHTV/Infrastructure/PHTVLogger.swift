//
//  PHTVLogger.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import OSLog

/// Logger thông minh cho PHTV với cơ chế tự dọn dẹp
/// Thread-safe: Uses serial queue for file operations and NSLock for shared state
final class PHTVLogger: Sendable {
    static let shared = PHTVLogger()

    // MARK: - Properties

    private let logger: Logger
    private let logFileURL: URL
    private let maxLogFileSize: Int = 2 * 1024 * 1024  // 2MB max
    private let maxLogAge: TimeInterval = 24 * 60 * 60  // 24 giờ
    private let queue = DispatchQueue(label: "com.phamhungtien.phtv.logger", qos: .utility)

    nonisolated(unsafe) private var _lastCleanupDate: Date?
    private let lock = NSLock()
    private let cleanupInterval: TimeInterval = 60 * 60  // Dọn dẹp mỗi 1 giờ

    private var lastCleanupDate: Date? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _lastCleanupDate
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _lastCleanupDate = newValue
        }
    }

    // MARK: - Initialization

    private init() {
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.phamhungtien.phtv", category: "app")

        // Tạo thư mục logs
        let logsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PHTV/Logs", isDirectory: true)

        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        self.logFileURL = logsDir.appendingPathComponent("phtv_debug.log")

        // Dọn dẹp khi khởi động
        cleanupIfNeeded()
    }

    // MARK: - Public Logging Methods

    /// Log thông tin chung
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    /// Log debug (chỉ trong development)
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(message, level: .debug, file: file, function: function, line: line)
        #endif
    }

    /// Log cảnh báo
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }

    /// Log lỗi
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }

    /// Log lỗi nghiêm trọng
    func fault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .fault, file: file, function: function, line: line)
    }

    // MARK: - Category-specific Logging

    /// Log liên quan đến input
    func input(_ message: String) {
        logWithCategory("[Input] \(message)", level: .info)
    }

    /// Log liên quan đến sync/settings
    func sync(_ message: String) {
        logWithCategory("[Sync] \(message)", level: .info)
    }

    /// Log liên quan đến UI
    func ui(_ message: String) {
        logWithCategory("[UI] \(message)", level: .debug)
    }

    /// Log liên quan đến macro
    func macro(_ message: String) {
        logWithCategory("[Macro] \(message)", level: .info)
    }

    /// Log liên quan đến permission
    func permission(_ message: String) {
        logWithCategory("[Permission] \(message)", level: .notice)
    }

    // MARK: - File Logs

    /// Lấy tất cả log từ file (để hiển thị trong BugReportView)
    func getFileLogs() -> String {
        guard FileManager.default.fileExists(atPath: logFileURL.path),
              let content = try? String(contentsOf: logFileURL, encoding: .utf8) else {
            return ""
        }
        return content
    }

    /// Xóa tất cả log
    func clearLogs() {
        let logFileURL = self.logFileURL
        queue.async {
            try? FileManager.default.removeItem(at: logFileURL)
        }
    }

    // MARK: - Private Methods

    private enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case notice = "NOTICE"
        case warning = "WARNING"
        case error = "ERROR"
        case fault = "FAULT"
    }

    private func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let formattedMessage = "[PHTV] [\(fileName)] \(message)"

        // Log to OSLog (unified logging)
        switch level {
        case .debug:
            logger.debug("\(formattedMessage)")
        case .info:
            logger.info("\(formattedMessage)")
        case .notice:
            logger.notice("\(formattedMessage)")
        case .warning:
            logger.warning("\(formattedMessage)")
        case .error:
            logger.error("\(formattedMessage)")
        case .fault:
            logger.fault("\(formattedMessage)")
        }

        // Also log to file for persistence
        writeToFile(formattedMessage, level: level)

        // Periodic cleanup
        cleanupIfNeeded()
    }

    private func logWithCategory(_ message: String, level: LogLevel) {
        let formattedMessage = "[PHTV] \(message)"

        switch level {
        case .debug:
            logger.debug("\(formattedMessage)")
        case .info:
            logger.info("\(formattedMessage)")
        case .notice:
            logger.notice("\(formattedMessage)")
        case .warning:
            logger.warning("\(formattedMessage)")
        case .error:
            logger.error("\(formattedMessage)")
        case .fault:
            logger.fault("\(formattedMessage)")
        }

        writeToFile(formattedMessage, level: level)
        cleanupIfNeeded()
    }

    private func writeToFile(_ message: String, level: LogLevel) {
        let logFileURL = self.logFileURL
        queue.async {
            let timestamp = Self.dateFormatter.string(from: Date())
            let logLine = "[\(timestamp)] [\(level.rawValue)] \(message)\n"

            if let data = logLine.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFileURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        try? fileHandle.close()
                    }
                } else {
                    try? data.write(to: logFileURL)
                }
            }
        }
    }

    private func cleanupIfNeeded() {
        // Chỉ dọn dẹp theo interval
        if let lastCleanup = lastCleanupDate,
           Date().timeIntervalSince(lastCleanup) < cleanupInterval {
            return
        }

        queue.async { [self] in
            self.performCleanup()
        }
    }

    private func performCleanup() {
        lastCleanupDate = Date()

        guard FileManager.default.fileExists(atPath: logFileURL.path) else { return }

        // Kiểm tra kích thước file
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
           let fileSize = attrs[.size] as? Int,
           fileSize > maxLogFileSize {
            // File quá lớn - giữ lại 50% cuối
            trimLogFile()
        }

        // Xóa log cũ hơn 24 giờ
        removeOldLogEntries()
    }

    private func trimLogFile() {
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else { return }

        let lines = content.components(separatedBy: "\n")
        let keepCount = lines.count / 2  // Giữ 50%
        let trimmedContent = lines.suffix(keepCount).joined(separator: "\n")

        try? trimmedContent.write(to: logFileURL, atomically: true, encoding: .utf8)
    }

    private func removeOldLogEntries() {
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else { return }

        let cutoffDate = Date().addingTimeInterval(-maxLogAge)
        let lines = content.components(separatedBy: "\n")

        let filteredLines = lines.filter { line in
            guard let timestamp = extractTimestamp(from: line) else { return true }
            return timestamp > cutoffDate
        }

        if filteredLines.count < lines.count {
            let newContent = filteredLines.joined(separator: "\n")
            try? newContent.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }

    private func extractTimestamp(from line: String) -> Date? {
        // Format: [2026-01-15 12:30:45.123]
        guard line.hasPrefix("["),
              let endBracket = line.firstIndex(of: "]") else { return nil }

        let timestampStr = String(line[line.index(after: line.startIndex)..<endBracket])
        return Self.dateFormatter.date(from: timestampStr)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Global Convenience Functions

/// Log info
func PHLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    PHTVLogger.shared.info(message, file: file, function: function, line: line)
}

/// Log error
func PHLogError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    PHTVLogger.shared.error(message, file: file, function: function, line: line)
}

/// Log warning
func PHLogWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    PHTVLogger.shared.warning(message, file: file, function: function, line: line)
}
