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
            .onAppear {
                // Trigger bounce animation once on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateIcon = true
                }
            }
            .sheet(isPresented: $showReleaseNotes) {
                ReleaseNotesView(info: info)
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        // Icon with white/neutral background
        ZStack {
            PHTVRoundedRect(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    PHTVRoundedRect(cornerRadius: 12)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 1)
                )
                .frame(width: 48, height: 48)

            if #available(macOS 14.0, *) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.bounce, value: animateIcon)
            } else {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)
            }
        }
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

            // Close button with glass effect
            GlassCloseButton {
                dismissBanner()
            }
        }
    }

    @ViewBuilder
    private var bannerBackground: some View {
        let fallback = Color(NSColor.controlBackgroundColor).opacity(colorScheme == .light ? 0.92 : 0.6)
        if SettingsVisualEffects.enableMaterials, !reduceTransparency {
            PHTVRoundedRect(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    PHTVRoundedRect(cornerRadius: 16)
                        .stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                )
        } else {
            PHTVRoundedRect(cornerRadius: 16)
                .fill(fallback)
                .overlay(
                    PHTVRoundedRect(cornerRadius: 16)
                        .stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                )
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
        .environmentObject(AppState.shared)
}
