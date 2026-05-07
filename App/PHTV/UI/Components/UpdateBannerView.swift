//
//  UpdateBannerView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct UpdateBannerView: View {
    @Environment(AppState.self) private var appState
    @State private var showReleaseNotes = false
    @State private var animateIcon = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let info = appState.customUpdateBannerInfo, appState.showCustomUpdateBanner {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Icon with Liquid Glass and bounce effect
                    iconView

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

                    // Actions with glass effects
                    actionsView
                }
                .padding(16)
                .background {
                    bannerBackground
                }
                .padding()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.phtvMorph, value: appState.showCustomUpdateBanner)
            .task(id: info.version) {
                animateIcon = false
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                animateIcon = true
            }
            .sheet(isPresented: $showReleaseNotes) {
                ReleaseNotesView(info: info)
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        Image(systemName: "arrow.down.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(Color.accentColor)
            .symbolEffect(.bounce, value: animateIcon)
            .frame(width: 40, height: 40)
    }

    @ViewBuilder
    private var actionsView: some View {
        HStack(spacing: 12) {
            Button {
                showReleaseNotes = true
            } label: {
                Text("Chi tiết")
            }
            .adaptiveBorderedButtonStyle()

            Button {
                installUpdate()
            } label: {
                Text("Cập nhật")
            }
            .adaptiveProminentButtonStyle()

            Button {
                dismissBanner()
            } label: {
                Image(systemName: "xmark")
            }
            .adaptiveBorderedButtonStyle()
            .controlSize(.small)
            .help("Đóng")
        }
    }

    @ViewBuilder
    private var bannerBackground: some View {
        let fallback = Color(NSColor.controlBackgroundColor).opacity(colorScheme == .light ? 0.92 : 0.6)
        if SettingsVisualEffects.enableMaterials, !reduceTransparency {
            Rectangle()
                .fill(.regularMaterial)
        } else {
            fallback
        }
    }

    private func installUpdate() {
        // Notify Sparkle to proceed with update installation
        NotificationCenter.default.post(
            name: NotificationName.sparkleInstallUpdate,
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
        .environment(AppState.shared)
}
