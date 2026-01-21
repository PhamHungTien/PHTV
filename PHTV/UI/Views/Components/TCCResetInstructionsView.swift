//
//  TCCResetInstructionsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

/// View that displays instructions for resetting TCC entry when it's corrupt
struct TCCResetInstructionsView: View {
    @State private var showCopiedFeedback = false
    @State private var isFixing = false
    @State private var showSuccessMessage = false
    @State private var showErrorMessage = false
    @State private var errorText = ""

    private let resetCommand = "tccutil reset Accessibility com.phamhungtien.phtv"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Phát hiện lỗi TCC Database")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("PHTV không xuất hiện trong danh sách Accessibility của System Settings")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Success/Error messages
            if showSuccessMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Đã fix thành công! Vui lòng khởi động lại PHTV và cấp quyền.")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
                .padding(8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }

            if showErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Không thể tự động fix")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                        Text(errorText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }

            Divider()

            // Auto-fix option (prominent)
            VStack(alignment: .leading, spacing: 12) {
                Text("Cách 1: Tự động khắc phục (Khuyến nghị)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Click nút bên dưới để tự động fix")
                            .font(.subheadline)
                        Text("Bạn sẽ được yêu cầu nhập password quản trị viên")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if #available(macOS 26.0, *) {
                        Button(action: autoFixTCC) {
                            HStack {
                                if isFixing {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                }
                                Text(isFixing ? "Đang fix..." : "Tự động khắc phục")
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                        .disabled(isFixing)
                    } else {
                        Button(action: autoFixTCC) {
                            HStack {
                                if isFixing {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                }
                                Text(isFixing ? "Đang fix..." : "Tự động khắc phục")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isFixing)
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            Divider()

            // Manual instructions (fallback)
            VStack(alignment: .leading, spacing: 12) {
                Text("Cách 2: Thủ công (nếu cách 1 không hoạt động)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    instructionStep(number: 1, text: "Mở Terminal (⌘ + Space, gõ \"Terminal\")")
                    instructionStep(number: 2, text: "Copy và chạy lệnh sau:")

                    // Command box
                    HStack(spacing: 8) {
                        Text(resetCommand)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)

                        Button(action: copyCommand) {
                            Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                .foregroundStyle(showCopiedFeedback ? .green : .primary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy lệnh")
                    }

                    instructionStep(number: 3, text: "Khởi động lại PHTV")
                    instructionStep(number: 4, text: "Cấp quyền Accessibility như bình thường")
                }
            }

            Divider()

            // Why this happens
            VStack(alignment: .leading, spacing: 8) {
                Text("Tại sao xảy ra lỗi này?")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("TCC database entry có thể bị corrupt do:\n• Update macOS hoặc PHTV\n• Ứng dụng dọn dẹp hệ thống (CleanMyMac, v.v.)\n• Thay đổi code signature của app\n• Lỗi của macOS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Manual action buttons
            HStack(spacing: 12) {
                Button("Copy lệnh") {
                    copyCommand()
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("Mở Terminal") {
                    openTerminal()
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
                    .glassEffect(in: .rect(cornerRadius: 12))
            } else {
                Color.red.opacity(0.1)
                    .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(resetCommand, forType: .string)

        // Show feedback
        withAnimation {
            showCopiedFeedback = true
        }

        // Hide feedback after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }

    private func openTerminal() {
        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open(terminalURL)
    }

    private func autoFixTCC() {
        // Reset states
        showSuccessMessage = false
        showErrorMessage = false
        isFixing = true

        // Run on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Call Objective-C method using Swift's do-catch pattern
            let success: Bool
            var capturedError: Error?

            do {
                try PHTVManager.autoFixTCCEntry()
                success = true
            } catch {
                success = false
                capturedError = error
            }

            // Update UI on main thread
            DispatchQueue.main.async {
                isFixing = false

                if success {
                    withAnimation {
                        showSuccessMessage = true
                        showErrorMessage = false
                    }

                    // Show alert to restart app
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showRestartAlert()
                    }
                } else {
                    let errorMessage: String
                    if let error = capturedError as? NSError {
                        if error.code == -128 {
                            errorMessage = "Bạn đã hủy thao tác. Vui lòng thử lại hoặc dùng cách thủ công."
                        } else {
                            errorMessage = "Lỗi: \(error.localizedDescription)"
                        }
                    } else {
                        errorMessage = "Vui lòng thử cách thủ công bên dưới."
                    }

                    withAnimation {
                        showErrorMessage = true
                        errorText = errorMessage
                        showSuccessMessage = false
                    }
                }
            }
        }
    }

    private func showRestartAlert() {
        let alert = NSAlert()
        alert.messageText = "Khắc phục thành công!"
        alert.informativeText = "TCC database đã được reset. Bạn cần khởi động lại PHTV để áp dụng thay đổi.\n\nSau khi khởi động lại, hãy cấp quyền Accessibility như bình thường."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Khởi động lại ngay")
        alert.addButton(withTitle: "Để sau")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Restart app
            let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
            let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [path]
            task.launch()
            exit(0)
        }
    }
}

#Preview("TCC Reset Instructions") {
    TCCResetInstructionsView()
        .padding()
        .frame(width: 600)
}
