//
//  AboutView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct AboutView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Icon and Name
                VStack(spacing: 16) {
                    ZStack {
                        if #available(macOS 26.0, *) {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.blue.opacity(0.12), Color.purple.opacity(0.12),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .glassEffect(in: .rect(cornerRadius: 28))
                        } else {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.blue.opacity(0.2), Color.purple.opacity(0.2),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                        }

                        AppIconView()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }

                    VStack(spacing: 8) {
                        Text("PHTV")
                            .font(.system(size: 32, weight: .bold, design: .rounded))

                        Text("Bộ gõ tiếng Việt cho macOS")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    // Version Badge
                    HStack(spacing: 8) {
                        Text("Phiên bản")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(
                            "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0")"
                        )
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                        .foregroundStyle(.tint)
                    }
                }
                .padding(.top, 20)

                Divider()
                    .padding(.horizontal, 40)

                // Developer Info
                VStack(spacing: 16) {
                    AboutInfoCard(
                        icon: "person.circle.fill",
                        iconColor: themeManager.themeColor,
                        title: "Phát triển bởi",
                        value: "Phạm Hùng Tiến"
                    )

                    AboutInfoCard(
                        icon: "calendar.circle.fill",
                        iconColor: themeManager.themeColor,
                        title: "Phát hành",
                        value: "2026"
                    )

                    AboutInfoCard(
                        icon: "swift",
                        iconColor: themeManager.themeColor,
                        title: "Công nghệ",
                        value: "Swift & SwiftUI"
                    )
                }
                .padding(.horizontal, 20)

                Divider()
                    .padding(.horizontal, 40)

                // Support Section
                VStack(spacing: 16) {
                    Text("Ủng hộ phát triển")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(
                        "Nếu bạn thấy PHTV hữu ích, hãy ủng hộ để giúp phát triển thêm các tính năng mới"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                    if let donateImage = NSImage(named: "donate") {
                        VStack(spacing: 8) {
                            Image(nsImage: donateImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                            Text("Quét mã để ủng hộ")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 20)

                // Footer
                VStack(spacing: 6) {
                    Text("Copyright © 2026 Phạm Hùng Tiến")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("All rights reserved")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct AboutInfoCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if #available(macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.08))
                        .frame(width: 42, height: 42)
                        .glassEffect(in: .rect(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 42, height: 42)
                }

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(14)
        .background {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.08))
                    .glassEffect(in: .rect(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            }
        }
    }
}

// MARK: - App Icon View
private struct AppIconView: View {
    var body: some View {
        if let iconPath = Bundle.main.path(forResource: "Icon", ofType: "icns"),
            let icon = NSImage(contentsOfFile: iconPath)
        {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else if let icon = NSApp.applicationIconImage {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else if let icon = NSImage(named: NSImage.applicationIconName) {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            // Fallback
            Image(systemName: "square.fill")
                .font(.system(size: 50))
                .foregroundStyle(.tint)
        }
    }
}

#Preview {
    AboutView()
        .frame(width: 500, height: 700)
}
