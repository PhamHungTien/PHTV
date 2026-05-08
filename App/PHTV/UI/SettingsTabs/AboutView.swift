//
//  AboutView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct AboutView: View {
    @State private var showDonateQR = false
    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: SettingsLayout.sectionSpacing) {
                SettingsCard(
                    title: "Ứng dụng",
                    subtitle: "Bộ gõ tiếng Việt dành cho macOS",
                    icon: "app"
                ) {
                    HStack(alignment: .center, spacing: 14) {
                        AppIconView()
                            .frame(width: 56, height: 56)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("PHTV")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Precision Hybrid Typing Vietnamese")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Phiên bản \(versionString)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }

                        Spacer(minLength: 0)
                    }
                }

                SettingsCard(
                    title: "Thông tin",
                    subtitle: "Thông tin phát triển và nền tảng",
                    icon: "info.circle"
                ) {
                    VStack(spacing: 0) {
                        AboutInfoRow(title: "Phát triển bởi", value: "Phạm Hùng Tiến")
                        SettingsDivider()
                        AboutInfoRow(title: "Năm phát hành", value: "2025")
                        SettingsDivider()
                        AboutInfoRow(title: "Công nghệ sử dụng", value: "Swift & SwiftUI")
                    }
                }

                SettingsCard(
                    title: "Hỗ trợ phát triển",
                    subtitle: "Ủng hộ để PHTV tiếp tục được cải thiện",
                    icon: "heart"
                ) {
                    SettingsButtonRow(
                        icon: "qrcode",
                        iconColor: .accentColor,
                        title: "Hiển thị QR ủng hộ",
                        subtitle: "Mở mã QR ủng hộ phát triển PHTV"
                    ) {
                        showDonateQR.toggle()
                    }
                    .popover(isPresented: $showDonateQR, arrowEdge: .bottom) {
                        DonateQRPopoverView()
                    }
                }

                Spacer(minLength: SettingsLayout.sectionSpacing)

                // Footer
                VStack(spacing: 6) {
                    Text("Copyright © 2025 Phạm Hùng Tiến")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("All rights reserved")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: SettingsLayout.contentMaxWidth)
                .padding(.bottom, 20)
            }
            .settingsPageFrame()
        }
        .settingsBackground()
    }
}

private struct AboutInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 12)

            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .lineLimit(2)
                .frame(width: SettingsLayout.rowControlColumnWidth, alignment: .trailing)
        }
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }
}

// MARK: - Donate QR Popover View

struct DonateQRPopoverView: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("Ủng hộ phát triển")
                .font(.headline)

            if let donateImage = NSImage(named: "donate") {
                Image(nsImage: donateImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 210, height: 210)
            }

            Text("Quét mã để ủng hộ")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(SettingsLayout.contentPadding)
        .frame(width: 260)
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
