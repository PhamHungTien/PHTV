//
//  PermissionWarningView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct PermissionWarningView: View {
    let hasPermission: Bool

    var body: some View {
        if hasPermission {
            // Success state
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Đã cấp quyền thành công")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("PHTV đã sẵn sàng hoạt động")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background {
                if #available(macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                        .glassEffect(in: .rect(cornerRadius: 12))
                } else {
                    Color.green.opacity(0.1)
                        .cornerRadius(8)
                }
            }
        } else {
            // Warning state
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cần cấp quyền truy cập")
                            .font(.headline)

                        Text("PHTV cần quyền Accessibility để hoạt động")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if #available(macOS 26.0, *) {
                    Button("Mở Cài đặt Hệ thống") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.orange)
                } else {
                    Button("Mở Cài đặt Hệ thống") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background {
                if #available(macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                        .glassEffect(in: .rect(cornerRadius: 12))
                } else {
                    Color.orange.opacity(0.1)
                        .cornerRadius(8)
                }
            }
        }
    }
}

#Preview("Chưa cấp quyền") {
    PermissionWarningView(hasPermission: false)
        .padding()
}

#Preview("Đã cấp quyền") {
    PermissionWarningView(hasPermission: true)
        .padding()
}
