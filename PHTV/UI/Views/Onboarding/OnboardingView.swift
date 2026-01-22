//
//  OnboardingView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @State private var currentStep: Int = 0

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            // Header with progress
            OnboardingHeader(
                currentStep: currentStep,
                totalSteps: totalSteps,
                onSkip: completeOnboarding
            )

            // Content
            TabView(selection: $currentStep) {
                // Step 0: Chào mừng
                WelcomeStepView()
                    .tag(0)

                // Step 1: Chọn phương pháp gõ
                InputMethodStepView()
                    .tag(1)

                // Step 2: Tính năng cơ bản
                BasicFeaturesStepView()
                    .tag(2)

                // Step 3: Cấp quyền Accessibility
                AccessibilityStepView()
                    .tag(3)

                // Step 4: Hoàn tất
                CompleteStepView()
                    .tag(4)
            }
            .tabViewStyle(.automatic)
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            // Footer with navigation buttons
            OnboardingFooter(
                currentStep: $currentStep,
                totalSteps: totalSteps,
                isLastStep: currentStep == totalSteps - 1,
                onComplete: completeOnboarding
            )
        }
        .frame(width: 580, height: 560)
        .background {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .glassEffect(in: .rect(cornerRadius: 16))
            } else {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.onboardingCompleted)
        UserDefaults.standard.synchronize()

        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

// MARK: - Step 0: Welcome

private struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // App Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "keyboard.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.accentColor)
            }

            // Title & Subtitle
            VStack(spacing: 8) {
                Text("Chào mừng đến với PHTV")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Bộ gõ tiếng Việt hiện đại, nhanh và thông minh cho macOS")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Feature highlights
            VStack(spacing: 12) {
                WelcomeFeatureRow(
                    icon: "hare.fill",
                    iconColor: .green,
                    title: "Nhanh chóng",
                    description: "Gõ tiếng Việt mượt mà, không giật lag"
                )

                WelcomeFeatureRow(
                    icon: "brain.head.profile",
                    iconColor: .purple,
                    title: "Thông minh",
                    description: "Tự động nhận diện từ tiếng Anh"
                )

                WelcomeFeatureRow(
                    icon: "sparkles",
                    iconColor: .orange,
                    title: "Hiện đại",
                    description: "Giao diện đẹp với hiệu ứng Liquid Glass"
                )
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()
        }
        .padding(.top, 16)
    }
}

private struct WelcomeFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
    }
}

// MARK: - Step 1: Input Method Selection

private struct InputMethodStepView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                OnboardingStepHeader(
                    icon: "character.cursor.ibeam",
                    iconColor: .green,
                    title: "Chọn phương pháp gõ",
                    subtitle: "Chọn kiểu gõ phù hợp với thói quen của bạn"
                )

                // Input Method Selection
                OnboardingCard {
                    VStack(spacing: 12) {
                        ForEach(InputMethod.allCases) { method in
                            InputMethodOptionRow(
                                method: method,
                                isSelected: appState.inputMethod == method,
                                onSelect: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        appState.inputMethod = method
                                    }
                                }
                            )
                        }
                    }
                }

                // Code Table Selection
                OnboardingCard {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 36, height: 36)

                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bảng mã")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("Chọn bảng mã ký tự")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Picker("", selection: $appState.codeTable) {
                            ForEach(CodeTable.allCases) { table in
                                Text(table.displayName).tag(table)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }
}

private struct InputMethodOptionRow: View {
    let method: InputMethod
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(method.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(methodDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var methodDescription: String {
        switch method {
        case .telex:
            return "Gõ dấu bằng chữ: aa → â, ow → ơ, s → sắc"
        case .vni:
            return "Gõ dấu bằng số: a1 → á, a2 → à, a6 → â"
        case .simpleTelex1:
            return "Dùng [ ] ; ' . để gõ dấu"
        case .simpleTelex2:
            return "Dùng 1 2 3 4 5 để gõ dấu"
        }
    }
}

// MARK: - Step 2: Basic Features

private struct BasicFeaturesStepView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                OnboardingStepHeader(
                    icon: "star.fill",
                    iconColor: .orange,
                    title: "Tính năng cơ bản",
                    subtitle: "Bật/tắt các tính năng theo nhu cầu của bạn"
                )

                // Features Card
                OnboardingCard {
                    VStack(spacing: 0) {
                        OnboardingToggleRow(
                            icon: "text.badge.checkmark",
                            iconColor: .blue,
                            title: "Kiểm tra chính tả",
                            subtitle: "Tự động phát hiện lỗi chính tả",
                            isOn: $appState.checkSpelling
                        )

                        OnboardingDivider()

                        OnboardingToggleRow(
                            icon: "arrow.uturn.left.circle.fill",
                            iconColor: .purple,
                            title: "Khôi phục từ sai",
                            subtitle: "Khôi phục ký tự khi từ không hợp lệ",
                            isOn: $appState.restoreOnInvalidWord
                        )

                        OnboardingDivider()

                        OnboardingToggleRow(
                            icon: "textformat.abc.dottedunderline",
                            iconColor: .green,
                            title: "Nhận diện tiếng Anh",
                            subtitle: "Tự động khôi phục từ tiếng Anh",
                            isOn: $appState.autoRestoreEnglishWord
                        )

                        OnboardingDivider()

                        OnboardingToggleRow(
                            icon: "textformat.abc",
                            iconColor: .orange,
                            title: "Viết hoa ký tự đầu",
                            subtitle: "Tự động viết hoa sau dấu chấm",
                            isOn: $appState.upperCaseFirstChar
                        )

                        OnboardingDivider()

                        OnboardingToggleRow(
                            icon: "hare.fill",
                            iconColor: .pink,
                            title: "Gõ nhanh (Quick Telex)",
                            subtitle: "cc → ch, gg → gi, nn → ng...",
                            isOn: $appState.quickTelex
                        )
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Step 3: Accessibility Permission

private struct AccessibilityStepView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                OnboardingStepHeader(
                    icon: "hand.raised.fill",
                    iconColor: .purple,
                    title: "Cấp quyền Accessibility",
                    subtitle: "PHTV cần quyền này để có thể gõ tiếng Việt"
                )

                // Status Card
                OnboardingCard {
                    HStack(spacing: 14) {
                        Image(systemName: appState.hasAccessibilityPermission ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(appState.hasAccessibilityPermission ? .green : .orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.hasAccessibilityPermission ? "Đã được cấp quyền" : "Chưa được cấp quyền")
                                .font(.headline)

                            Text(appState.hasAccessibilityPermission ? "PHTV đã sẵn sàng hoạt động" : "Vui lòng cấp quyền để sử dụng")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !appState.hasAccessibilityPermission {
                            Button("Cấp quyền") {
                                openAccessibilitySettings()
                            }
                            .adaptiveProminentButtonStyle()
                        }
                    }
                }

                // Instructions Card
                if !appState.hasAccessibilityPermission {
                    OnboardingCard {
                        VStack(spacing: 12) {
                            InstructionRow(step: 1, text: "Mở System Settings > Privacy & Security")
                            OnboardingDivider()
                            InstructionRow(step: 2, text: "Chọn Accessibility trong danh sách")
                            OnboardingDivider()
                            InstructionRow(step: 3, text: "Bật PHTV trong danh sách ứng dụng")
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct InstructionRow: View {
    let step: Int
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 28, height: 28)

                Text("\(step)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Step 4: Complete

private struct CompleteStepView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.green)
            }

            // Title
            VStack(spacing: 8) {
                Text("Sẵn sàng sử dụng!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Bạn đã hoàn tất thiết lập PHTV")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            // Quick tips
            OnboardingCard {
                VStack(spacing: 0) {
                    QuickTipRow(
                        icon: "command",
                        title: "Chuyển ngôn ngữ",
                        value: "Control + Shift"
                    )

                    OnboardingDivider()

                    QuickTipRow(
                        icon: "face.smiling.fill",
                        title: "PHTV Picker",
                        value: "⌘E"
                    )

                    OnboardingDivider()

                    QuickTipRow(
                        icon: "menubar.rectangle",
                        title: "Truy cập nhanh",
                        value: "Click icon menu bar"
                    )
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 8)
    }
}

private struct QuickTipRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Shared Components

private struct OnboardingStepHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 8)
    }
}

private struct OnboardingCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity)
            .background {
                if #available(macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .glassEffect(in: .rect(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                }
            }
    }
}

private struct OnboardingToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(iconColor)
        }
        .padding(.vertical, 4)
    }
}

private struct OnboardingDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 50)
    }
}

// MARK: - Onboarding Header

struct OnboardingHeader: View {
    let currentStep: Int
    let totalSteps: Int
    let onSkip: () -> Void

    var body: some View {
        HStack {
            // Progress indicator
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: index == currentStep ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }

            Spacer()

            // Skip button
            Button("Bỏ qua") {
                onSkip()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.subheadline)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

// MARK: - Onboarding Footer

struct OnboardingFooter: View {
    @Binding var currentStep: Int
    let totalSteps: Int
    let isLastStep: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack {
            // Back button
            if currentStep > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep -= 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Quay lại")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            } else {
                Spacer()
                    .frame(width: 100)
            }

            Spacer()

            // Next/Complete button
            Button {
                if isLastStep {
                    onComplete()
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep += 1
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(isLastStep ? "Bắt đầu sử dụng" : "Tiếp tục")
                    if !isLastStep {
                        Image(systemName: "chevron.right")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .adaptiveProminentButtonStyle()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, 8)
    }
}

// MARK: - Onboarding Container

struct OnboardingContainer<Content: View>: View {
    @Binding var showOnboarding: Bool
    let content: Content

    init(showOnboarding: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._showOnboarding = showOnboarding
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .blur(radius: showOnboarding ? 3 : 0)
                .allowsHitTesting(!showOnboarding)

            if showOnboarding {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)

                OnboardingView(isPresented: $showOnboarding)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showOnboarding)
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
        .environmentObject(AppState.shared)
        .frame(width: 600, height: 580)
}
