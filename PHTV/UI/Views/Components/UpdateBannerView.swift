//
//  UpdateBannerView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct UpdateBannerView: View {
    @EnvironmentObject var appState: AppState
    @State private var showReleaseNotes = false

    var body: some View {
        if let info = appState.customUpdateBannerInfo, appState.showCustomUpdateBanner {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Icon with bounce effect on macOS 15+
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 48, height: 48)

                        if #available(macOS 26.0, *) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.accentColor)
                                .symbolEffect(.bounce, options: .repeat(2))
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    // Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bản cập nhật mới có sẵn")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("PHTV \(info.version)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Actions
                    HStack(spacing: 12) {
                        Button {
                            showReleaseNotes = true
                        } label: {
                            Text("Chi tiết")
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.borderless)

                        Button {
                            installUpdate()
                        } label: {
                            Text("Cập nhật")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.borderless)

                        Button {
                            dismissBanner()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(16)
                .background {
                    if #available(macOS 26.0, *) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .glassEffect(in: .rect(cornerRadius: 16))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    }
                }
                .padding()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.showCustomUpdateBanner)
            .sheet(isPresented: $showReleaseNotes) {
                ReleaseNotesView(info: info)
            }
        }
    }

    private func installUpdate() {
        // Notify Sparkle to proceed with update installation
        NotificationCenter.default.post(
            name: NSNotification.Name("SparkleInstallUpdate"),
            object: nil
        )
        // Dismiss banner - Sparkle will show its own UI
        dismissBanner()
    }

    private func dismissBanner() {
        withAnimation {
            appState.showCustomUpdateBanner = false
        }
    }
}

#Preview {
    UpdateBannerView()
        .environmentObject(AppState.shared)
}
