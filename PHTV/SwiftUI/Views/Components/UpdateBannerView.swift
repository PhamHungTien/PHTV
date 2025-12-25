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
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showReleaseNotes = false

    var body: some View {
        if let info = appState.customUpdateBannerInfo, appState.showCustomUpdateBanner {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.themeColor.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(themeManager.themeColor)
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
                        Button("Chi tiết") {
                            showReleaseNotes = true
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(themeManager.themeColor)

                        Button {
                            installUpdate()
                        } label: {
                            Text("Cập nhật")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(themeManager.themeColor)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            dismissBanner()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
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
                    .environmentObject(themeManager)
            }
        }
    }

    private func installUpdate() {
        // Sparkle handles installation automatically
        // Just dismiss banner - user will be prompted by Sparkle
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
        .environmentObject(ThemeManager.shared)
}
