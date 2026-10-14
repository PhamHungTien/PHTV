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
        PHTVBuildInfo.displayVersion
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

                            Text("Bộ gõ tiếng Việt cho macOS")
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
                        AboutContactRow(
                            title: "Fanpage",
                            label: "PHTV",
                            destination: URL(string: "https://www.facebook.com/PHTVInput")!
                        )
                        SettingsDivider()
                        AboutContactRow(
                            title: "Email",
                            label: "contact@phamhungtien.com",
                            destination: URL(string: "mailto:contact@phamhungtien.com")!
                        )
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
        SettingsRowLayout {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
    }
}

private struct AboutContactRow: View {
    let title: String
    let label: String
    let destination: URL

    var body: some View {
        SettingsRowLayout {
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
            Link(label, destination: destination)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .help(destination.absoluteString)
        }
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
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
