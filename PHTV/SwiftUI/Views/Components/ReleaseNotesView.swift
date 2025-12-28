//
//  ReleaseNotesView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import WebKit

struct ReleaseNotesView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    let info: UpdateBannerInfo

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ghi chú phát hành")
                        .font(.title2.bold())

                    Text("Phiên bản \(info.version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                ReleaseNotesHTML(html: info.releaseNotes)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Đóng") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    if let url = URL(string: info.downloadURL) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Tải xuống", systemImage: "arrow.down.circle.fill")
                }
                .keyboardShortcut(.defaultAction)
                .tint(themeManager.themeColor)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
}

struct ReleaseNotesHTML: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let template = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    color: #333;
                    padding: 0;
                    margin: 0;
                }
                h3 {
                    font-size: 1.2em;
                    font-weight: 600;
                    margin: 1em 0 0.5em;
                    color: #1d1d1f;
                }
                h4 {
                    font-size: 1.1em;
                    font-weight: 600;
                    margin: 0.8em 0 0.4em;
                    color: #1d1d1f;
                }
                p {
                    margin: 0.5em 0;
                }
                ul {
                    padding-left: 1.5em;
                    margin: 0.5em 0;
                }
                li {
                    margin: 0.3em 0;
                }
                strong {
                    font-weight: 600;
                    color: #1d1d1f;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #e0e0e0;
                    }
                    h3, h4, strong {
                        color: #f5f5f7;
                    }
                }
            </style>
        </head>
        <body>\(html)</body>
        </html>
        """
        webView.loadHTMLString(template, baseURL: nil)
    }
}

#Preview {
    ReleaseNotesView(info: UpdateBannerInfo(
        version: "1.3.0",
        releaseNotes: "<h3>Tính năng mới</h3><ul><li>Tính năng A</li><li>Tính năng B</li></ul>",
        downloadURL: "https://github.com/PhamHungTien/PHTV/releases/latest"
    ))
    .environmentObject(ThemeManager.shared)
}
