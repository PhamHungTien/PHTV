//
//  TypingStatsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import Charts

struct TypingStatsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var statsManager = TypingStatsManager.shared
    @State private var showResetConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Summary Cards
                summarySection

                // Daily Chart
                chartSection

                // Language Distribution
                languageSection

                // Recent Activity
                recentActivitySection

                Spacer(minLength: 20)
            }
            .padding()
        }
        .settingsBackground()
        .alert("Xóa thống kê?", isPresented: $showResetConfirm) {
            Button("Hủy", role: .cancel) {}
            Button("Xóa", role: .destructive) {
                statsManager.resetStats()
            }
        } message: {
            Text("Tất cả thống kê gõ phím sẽ bị xóa. Hành động này không thể hoàn tác.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Thống kê gõ phím")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Theo dõi hoạt động gõ phím của bạn")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showResetConfirm = true
            } label: {
                Label("Xóa", systemImage: "trash")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatsCard(
                icon: "character.cursor.ibeam",
                title: "Tổng ký tự",
                value: statsManager.formatNumber(statsManager.stats.totalCharacters),
                color: themeManager.themeColor
            )

            StatsCard(
                icon: "text.word.spacing",
                title: "Tổng từ",
                value: statsManager.formatNumber(statsManager.stats.totalWords),
                color: .green
            )

            StatsCard(
                icon: "clock.fill",
                title: "Thời gian gõ",
                value: statsManager.formatTime(statsManager.stats.totalTypingTime),
                color: .orange
            )
        }
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7 ngày gần đây")
                .font(.headline)

            let chartData = statsManager.last7DaysStats

            if chartData.allSatisfy({ $0.stats.words == 0 }) {
                emptyChartView
            } else {
                Chart(chartData, id: \.date) { item in
                    BarMark(
                        x: .value("Ngày", formatChartDate(item.date)),
                        y: .value("Từ", item.stats.words)
                    )
                    .foregroundStyle(themeManager.themeColor.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyChartView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Chưa có dữ liệu")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Thống kê sẽ hiển thị khi bạn bắt đầu gõ phím")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Language Section

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phân bố ngôn ngữ")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 10, height: 10)
                        Text("Tiếng Việt")
                            .font(.subheadline)
                        Spacer()
                        Text(statsManager.formatNumber(statsManager.stats.vietnameseWords))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Circle()
                            .fill(.blue)
                            .frame(width: 10, height: 10)
                        Text("Tiếng Anh")
                            .font(.subheadline)
                        Spacer()
                        Text(statsManager.formatNumber(statsManager.stats.englishWords))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity)

                // Pie chart
                if statsManager.stats.totalWords > 0 {
                    ZStack {
                        Circle()
                            .trim(from: 0, to: CGFloat(statsManager.vietnamesePercentage / 100))
                            .stroke(.green, lineWidth: 20)
                            .rotationEffect(.degrees(-90))

                        Circle()
                            .trim(from: CGFloat(statsManager.vietnamesePercentage / 100), to: 1)
                            .stroke(.blue, lineWidth: 20)
                            .rotationEffect(.degrees(-90))

                        Text(String(format: "%.0f%%", statsManager.vietnamesePercentage))
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .frame(width: 80, height: 80)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hoạt động gần đây")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ActivityItem(
                    icon: "calendar",
                    title: "Hôm nay",
                    value: "\(statsManager.formatNumber(statsManager.todayStats.words)) từ"
                )

                ActivityItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Trung bình/ngày",
                    value: "\(Int(statsManager.averageWordsPerDay)) từ"
                )

                ActivityItem(
                    icon: "number",
                    title: "Phiên làm việc",
                    value: "\(statsManager.stats.sessionsCount)"
                )

                ActivityItem(
                    icon: "calendar.badge.clock",
                    title: "Ngày thống kê",
                    value: "\(statsManager.stats.dailyStats.count)"
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func formatChartDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "dd/MM"
            return formatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Stats Card Component

private struct StatsCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Activity Item Component

private struct ActivityItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    TypingStatsView()
        .environmentObject(ThemeManager.shared)
        .frame(width: 600, height: 700)
}
