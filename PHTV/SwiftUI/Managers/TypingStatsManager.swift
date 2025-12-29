//
//  TypingStatsManager.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Typing Statistics Data Models

struct TypingStats: Codable {
    var totalCharacters: Int = 0
    var totalWords: Int = 0
    var vietnameseWords: Int = 0
    var englishWords: Int = 0
    var sessionsCount: Int = 0
    var totalTypingTime: TimeInterval = 0
    var dailyStats: [String: DailyStats] = [:]
    var weeklyStats: [String: DailyStats] = [:]

    mutating func reset() {
        totalCharacters = 0
        totalWords = 0
        vietnameseWords = 0
        englishWords = 0
        sessionsCount = 0
        totalTypingTime = 0
        dailyStats = [:]
        weeklyStats = [:]
    }
}

struct DailyStats: Codable {
    var characters: Int = 0
    var words: Int = 0
    var vietnameseWords: Int = 0
    var englishWords: Int = 0
    var typingTime: TimeInterval = 0
}

// MARK: - Typing Statistics Manager

@MainActor
final class TypingStatsManager: ObservableObject {
    static let shared = TypingStatsManager()

    @Published var stats: TypingStats = TypingStats()
    @Published var currentSessionStart: Date?

    private let defaults = UserDefaults.standard
    private let statsKey = "typingStats"
    private var saveTimer: Timer?

    private init() {
        loadStats()
        startNewSession()
        setupAutoSave()
    }

    // MARK: - Session Management

    func startNewSession() {
        currentSessionStart = Date()
        stats.sessionsCount += 1
        saveStats()
    }

    func endSession() {
        if let start = currentSessionStart {
            let duration = Date().timeIntervalSince(start)
            stats.totalTypingTime += duration

            let today = todayKey()
            if stats.dailyStats[today] == nil {
                stats.dailyStats[today] = DailyStats()
            }
            stats.dailyStats[today]?.typingTime += duration
        }
        currentSessionStart = nil
        saveStats()
    }

    // MARK: - Recording Stats

    func recordCharacter() {
        stats.totalCharacters += 1

        let today = todayKey()
        if stats.dailyStats[today] == nil {
            stats.dailyStats[today] = DailyStats()
        }
        stats.dailyStats[today]?.characters += 1
    }

    func recordWord(isVietnamese: Bool) {
        stats.totalWords += 1

        if isVietnamese {
            stats.vietnameseWords += 1
        } else {
            stats.englishWords += 1
        }

        let today = todayKey()
        if stats.dailyStats[today] == nil {
            stats.dailyStats[today] = DailyStats()
        }
        stats.dailyStats[today]?.words += 1
        if isVietnamese {
            stats.dailyStats[today]?.vietnameseWords += 1
        } else {
            stats.dailyStats[today]?.englishWords += 1
        }
    }

    // MARK: - Computed Properties

    var todayStats: DailyStats {
        stats.dailyStats[todayKey()] ?? DailyStats()
    }

    var averageWordsPerDay: Double {
        guard !stats.dailyStats.isEmpty else { return 0 }
        let totalWords = stats.dailyStats.values.reduce(0) { $0 + $1.words }
        return Double(totalWords) / Double(stats.dailyStats.count)
    }

    var averageCharsPerDay: Double {
        guard !stats.dailyStats.isEmpty else { return 0 }
        let totalChars = stats.dailyStats.values.reduce(0) { $0 + $1.characters }
        return Double(totalChars) / Double(stats.dailyStats.count)
    }

    var vietnamesePercentage: Double {
        guard stats.totalWords > 0 else { return 0 }
        return Double(stats.vietnameseWords) / Double(stats.totalWords) * 100
    }

    var last7DaysStats: [(date: String, stats: DailyStats)] {
        var result: [(String, DailyStats)] = []
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let key = formatter.string(from: date)
                result.append((key, stats.dailyStats[key] ?? DailyStats()))
            }
        }

        return result.reversed()
    }

    // MARK: - Persistence

    func loadStats() {
        if let data = defaults.data(forKey: statsKey),
           let loadedStats = try? JSONDecoder().decode(TypingStats.self, from: data) {
            stats = loadedStats
        }
    }

    func saveStats() {
        if let encoded = try? JSONEncoder().encode(stats) {
            defaults.set(encoded, forKey: statsKey)
            defaults.synchronize()
        }
    }

    func resetStats() {
        stats.reset()
        saveStats()
    }

    // MARK: - Helpers

    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func setupAutoSave() {
        // Save every 30 seconds
        saveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.saveStats()
            }
        }
    }

    // MARK: - Format Helpers

    func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) phút"
        }
    }

    func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
