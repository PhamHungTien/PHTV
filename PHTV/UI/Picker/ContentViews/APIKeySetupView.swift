//
//  APIKeySetupView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct APIKeySetupView: View {
    @ObservedObject var klipyClient: KlipyAPIClient

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Cần Klipy App Key")
                .font(.headline)

            Text("Để sử dụng tính năng GIF, bạn cần lấy app key miễn phí từ Klipy (không giới hạn request).")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .padding(.vertical, 8)

            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Cách lấy app key miễn phí (< 60 giây):")
                    .font(.caption)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Mở Klipy Partner Portal")
                        .font(.caption2)
                    Text("2. Đăng nhập hoặc tạo account")
                        .font(.caption2)
                    Text("3. Vào API Keys section")
                        .font(.caption2)
                    Text("4. Copy app key")
                        .font(.caption2)
                    Text("5. Paste vào PHTVApp.swift (dòng 1694)")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)

                Button("Mở Klipy Partner Portal") {
                    if let url = URL(string: "https://partner.klipy.com/api-keys") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.caption)

                Text("Sau khi có app key, mở file PHTVApp.swift và thay 'YOUR_KLIPY_APP_KEY_HERE' bằng key của bạn.")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}
