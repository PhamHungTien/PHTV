//
//  BinaryIntegrityWarningView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct BinaryIntegrityWarningView: View {
    let architectureInfo: String
    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)

                Text("Ứng dụng đã bị chỉnh sửa")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            // Main warning message
            Text("PHTV phát hiện binary đã bị thay đổi bởi CleanMyMac hoặc công cụ tối ưu tương tự. Điều này có thể gây mất quyền Accessibility.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Technical details (collapsible)
            DisclosureGroup("Chi tiết kỹ thuật", isExpanded: $showDetails) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Kiến trúc binary:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(architectureInfo)
                            .font(.caption.monospaced())
                            .foregroundColor(.orange)
                    }

                    Text("Khi CleanMyMac gỡ bỏ Universal Binary (x86_64), macOS coi đây là app \"đã thay đổi\" và tự động thu hồi quyền Accessibility đã cấp.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
            }
            .tint(.orange)

            Divider()

            // Recommended solutions
            VStack(alignment: .leading, spacing: 8) {
                Text("Giải pháp khuyến nghị:")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 6) {
                    recommendationRow(
                        number: "1",
                        title: "Tắt tính năng gỡ Universal Binary trong CleanMyMac",
                        description: "Preferences > Uninstaller > bỏ tick \"Remove Universal Binaries\""
                    )

                    recommendationRow(
                        number: "2",
                        title: "Cài đặt lại PHTV từ bản gốc",
                        description: "Tải từ GitHub releases hoặc build lại từ source code"
                    )

                    recommendationRow(
                        number: "3",
                        title: "Thêm PHTV vào danh sách loại trừ",
                        description: "Ngăn CleanMyMac tự động tối ưu PHTV trong tương lai"
                    )
                }
            }

            Divider()

            // Action buttons
            HStack {
                Button(action: openCleanMyMacSettings) {
                    HStack(spacing: 4) {
                        Image(systemName: "gear")
                        Text("Mở CleanMyMac")
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: openGitHubReleases) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                        Text("Tải bản mới")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helper Views

    private func recommendationRow(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.orange))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func openCleanMyMacSettings() {
        // Try to open CleanMyMac app
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: "com.macpaw.CleanMyMac4") ??
                        workspace.urlForApplication(withBundleIdentifier: "com.macpaw.CleanMyMac") {
            workspace.open(appURL)
        } else {
            NSLog("CleanMyMac not found")
        }
    }

    private func openGitHubReleases() {
        if let url = URL(string: "https://github.com/YOUR_USERNAME/PHTV/releases") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    BinaryIntegrityWarningView(architectureInfo: "arm64 only (stripped by CleanMyMac?)")
        .frame(maxWidth: 500)
        .padding()
}
