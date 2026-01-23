//
//  OnboardingView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

private enum OnboardingStyle {
    static let cardCornerRadius: CGFloat = 26
    static let cardWidth: CGFloat = 780
    static let cardHeight: CGFloat = 560
    static let containerWidth: CGFloat = 840
    static let containerHeight: CGFloat = 620
    static let contentHorizontalPadding: CGFloat = 36
}

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    var onDismiss: () -> Void
    @State private var currentStep = 0

    // Steps definition
    private let totalSteps = 6
    private let stepTitles = [
        "Chào mừng",
        "Cấu hình hệ thống",
        "Kiểu gõ",
        "Tính năng",
        "Quyền truy cập",
        "Hoàn tất"
    ]

    private var stepLabel: String {
        let index = max(0, min(currentStep, stepTitles.count - 1))
        return "Bước \(currentStep + 1)/\(totalSteps) · \(stepTitles[index])"
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ZStack {
                switch currentStep {
                case 0:
                    WelcomeStepView()
                        .transition(stepTransition)
                case 1:
                    SystemSettingsStepView()
                        .transition(stepTransition)
                case 2:
                    InputMethodStepView()
                        .transition(stepTransition)
                case 3:
                    BasicFeaturesStepView()
                        .transition(stepTransition)
                case 4:
                    AccessibilityStepView()
                        .transition(stepTransition)
                case 5:
                    CompletionStepView(onFinish: {
                        onDismiss()
                    })
                    .transition(stepTransition)
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if currentStep < totalSteps - 1 {
                footer
            }
        }
        .background(OnboardingCardBackground())
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingStyle.cardCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 14)
        .padding(24)
        .frame(width: OnboardingStyle.cardWidth, height: OnboardingStyle.cardHeight)
        .frame(width: OnboardingStyle.containerWidth, height: OnboardingStyle.containerHeight)
    }

    private var header: some View {
        HStack(spacing: 16) {
            OnboardingAppBadge()

            VStack(alignment: .leading, spacing: 2) {
                Text("PHTV")
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Text("Thiết lập nhanh")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(stepLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                OnboardingProgressBar(currentStep: currentStep, totalSteps: totalSteps)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                if currentStep > 0 {
                    Button("Quay lại") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep -= 1
                        }
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .buttonStyle(OnboardingSecondaryButtonStyle())
                } else {
                    Spacer().frame(width: 96)
                }

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep += 1
                    }
                }) {
                    HStack(spacing: 8) {
                        Text(currentStep == 0 ? "Bắt đầu" : "Tiếp tục")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .frame(height: 64)
        }
    }
}

// MARK: - Visual Styles

struct OnboardingCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: OnboardingStyle.cardCornerRadius, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor))
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.65),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.35)
                .clipShape(RoundedRectangle(cornerRadius: OnboardingStyle.cardCornerRadius, style: .continuous))
            )
    }
}

struct OnboardingAppBadge: View {
    var body: some View {
        let image = NSApp.applicationIconImage ?? NSImage()
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.8))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
    }
}

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? AnyShapeStyle(activeGradient) : AnyShapeStyle(Color.gray.opacity(0.2)))
                    .frame(width: 22, height: 6)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: currentStep)
    }

    private var activeGradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .foregroundColor(.white)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundColor(.secondary)
            .background(
                Capsule()
                    .fill(Color.gray.opacity(configuration.isPressed ? 0.2 : 0.12))
            )
            .overlay(
                Capsule()
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
    }
}

struct OnboardingStepHeader: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            OnboardingIconBadge(symbol: icon)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, OnboardingStyle.contentHorizontalPadding)
        .padding(.top, 8)
    }
}

struct OnboardingIconBadge: View {
    let symbol: String

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)

            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.accentColor)
        }
        .overlay(
            Circle()
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Reusable Components

struct OnboardingHighlightCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)
            }

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text(subtitle)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct OptionCard: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    Text(description)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : Color.gray.opacity(0.4))
                    .padding(.top, 2)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.black.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct FeatureToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text(description)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct OnboardingChecklistCard: View {
    let title: String
    let subtitle: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
            }

            ForEach(items, id: \.self) { item in
                OnboardingChecklistItem(text: item)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

struct OnboardingChecklistItem: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
            Text(text)
                .font(.system(size: 12, design: .rounded))
        }
    }
}

struct OnboardingStatusCard: View {
    let icon: String
    let title: String
    let description: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Text(description)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

struct OnboardingNumberedRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.accentColor)
                .frame(width: 18, height: 18)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                )

            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Steps

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 4)

            VStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)

                Text("Chào mừng đến với PHTV")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text("Thiết lập nhanh trong chưa đầy 1 phút để tối ưu trải nghiệm gõ tiếng Việt mượt mà và ổn định.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
            }

            HStack(spacing: 12) {
                OnboardingHighlightCard(
                    icon: "bolt.fill",
                    title: "Nhanh & chính xác",
                    subtitle: "Tối ưu cho macOS"
                )

                OnboardingHighlightCard(
                    icon: "sparkles",
                    title: "Tuỳ biến linh hoạt",
                    subtitle: "Điều chỉnh theo thói quen"
                )

                OnboardingHighlightCard(
                    icon: "shield.fill",
                    title: "Ổn định lâu dài",
                    subtitle: "Giảm lỗi khi gõ"
                )
            }
            .padding(.horizontal, 32)

            Text("Bạn có thể thay đổi mọi thiết lập trong Cài đặt bất cứ lúc nào.")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

struct SystemSettingsStepView: View {
    @State private var showZoom = false

    var body: some View {
        VStack(spacing: 18) {
            OnboardingStepHeader(
                title: "Cấu hình hệ thống",
                subtitle: "Tắt một vài tính năng tự động để tránh xung đột khi gõ",
                icon: "gearshape.2.fill"
            )

            HStack(alignment: .top, spacing: 18) {
                OnboardingChecklistCard(
                    title: "Tắt các mục sau",
                    subtitle: "Bàn phím > Văn bản",
                    items: [
                        "Correct spelling automatically",
                        "Capitalize words automatically",
                        "Show inline predictive text",
                        "Add period with double-space",
                        "Use smart quotes and dashes"
                    ]
                )

                VStack(spacing: 10) {
                    ZStack(alignment: .bottomTrailing) {
                        Image("onboarding_system_settings")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 180)
                            .cornerRadius(12)
                            .shadow(radius: 4)

                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .padding(6)
                    }
                    .onTapGesture {
                        showZoom = true
                    }
                    .sheet(isPresented: $showZoom) {
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: { showZoom = false }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .padding()
                                .keyboardShortcut(.escape, modifiers: [])
                            }

                            Image("onboarding_system_settings")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(.horizontal)
                                .padding(.bottom)
                        }
                        .frame(minWidth: 800, minHeight: 600)
                    }

                    Text("Nhấn để phóng to")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, OnboardingStyle.contentHorizontalPadding)

            Button("Mở Cài đặt Bàn phím") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())

            Spacer()
        }
    }
}

struct InputMethodStepView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 18) {
            OnboardingStepHeader(
                title: "Chọn kiểu gõ",
                subtitle: "Hãy chọn kiểu gõ bạn quen thuộc nhất",
                icon: "keyboard.fill"
            )

            VStack(spacing: 12) {
                OptionCard(
                    title: "Telex",
                    description: "S, F, R, X, J để bỏ dấu. Phổ biến nhất.",
                    icon: "keyboard",
                    isSelected: appState.inputMethod == .telex
                ) {
                    appState.inputMethod = .telex
                }

                OptionCard(
                    title: "VNI",
                    description: "Sử dụng phím số 1, 2, 3... để bỏ dấu.",
                    icon: "textformat.123",
                    isSelected: appState.inputMethod == .vni
                ) {
                    appState.inputMethod = .vni
                }

                OptionCard(
                    title: "Simple Telex",
                    description: "Giản lược, giảm lỗi gõ nhầm trong tiếng Anh.",
                    icon: "wand.and.stars",
                    isSelected: appState.inputMethod == .simpleTelex1
                ) {
                    appState.inputMethod = .simpleTelex1
                }
            }
            .padding(.horizontal, OnboardingStyle.contentHorizontalPadding)

            Text("Bạn có thể đổi lại kiểu gõ trong Cài đặt bất cứ lúc nào.")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

struct BasicFeaturesStepView: View {
    @EnvironmentObject var appState: AppState

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 18) {
            OnboardingStepHeader(
                title: "Tính năng cơ bản",
                subtitle: "Bật nhanh các tính năng thường dùng",
                icon: "sparkles"
            )

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    FeatureToggleRow(
                        icon: "text.magnifyingglass",
                        title: "Kiểm tra chính tả",
                        description: "Tự động phát hiện và ngăn gõ sai từ tiếng Việt.",
                        isOn: $appState.checkSpelling
                    )

                    FeatureToggleRow(
                        icon: "bolt.fill",
                        title: "Gõ tắt (Macro)",
                        description: "Tăng tốc nhập liệu với bảng gõ tắt.",
                        isOn: $appState.useMacro
                    )

                    FeatureToggleRow(
                        icon: "arrow.2.squarepath",
                        title: "Chuyển chế độ thông minh",
                        description: "Tự nhớ kiểu gõ theo từng ứng dụng.",
                        isOn: $appState.useSmartSwitchKey
                    )

                    FeatureToggleRow(
                        icon: "globe",
                        title: "Phụ âm ngoài (Z, F, W, J)",
                        description: "Cho phép gõ các phụ âm mở rộng.",
                        isOn: $appState.allowConsonantZFWJ
                    )
                }
                .padding(.horizontal, OnboardingStyle.contentHorizontalPadding)
                .padding(.bottom, 12)
            }
        }
    }
}

struct AccessibilityStepView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            OnboardingStepHeader(
                title: "Cấp quyền truy cập",
                subtitle: "PHTV cần quyền Accessibility để gõ ổn định",
                icon: "hand.raised.fill"
            )

            VStack(spacing: 16) {
                if appState.hasAccessibilityPermission {
                    OnboardingStatusCard(
                        icon: "checkmark.seal.fill",
                        title: "Đã cấp quyền Accessibility",
                        description: "Mọi tính năng đã sẵn sàng hoạt động.",
                        tint: .green
                    )
                } else {
                    OnboardingStatusCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "Cần cấp quyền Accessibility",
                        description: "Bật quyền để PHTV có thể nhập liệu chính xác.",
                        tint: .orange
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Hướng dẫn nhanh")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))

                        OnboardingNumberedRow(number: "1", text: "Nhấn nút bên dưới để mở Cài đặt Hệ thống.")
                        OnboardingNumberedRow(number: "2", text: "Trong Accessibility, bật công tắc cho PHTV.")
                        OnboardingNumberedRow(number: "3", text: "Nếu đã bật nhưng chưa hoạt động, thử tắt rồi bật lại.")
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )

                    Button("Mở Cài đặt Quyền riêng tư") {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                }
            }
            .padding(.horizontal, OnboardingStyle.contentHorizontalPadding)

            Spacer()
        }
        .onAppear {
            appState.checkAccessibilityPermission()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            appState.checkAccessibilityPermission()
        }
    }
}

struct CompletionStepView: View {
    var onFinish: () -> Void
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 200, height: 200)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 90))
                    .foregroundColor(.accentColor)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }

            VStack(spacing: 12) {
                Text("Hoàn tất thiết lập")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("PHTV đã sẵn sàng. Bạn có thể mở Cài đặt để tinh chỉnh thêm bất cứ lúc nào.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 40)

            Spacer()

            Button(action: {
                UserDefaults.standard.set(true, forKey: UserDefaultsKey.onboardingCompleted)
                onFinish()
            }) {
                Text("Bắt đầu sử dụng")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(width: 200)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .padding(.bottom, 36)
        }
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
                .blur(radius: showOnboarding ? 6 : 0)
                .disabled(showOnboarding)

            if showOnboarding {
                OnboardingView(onDismiss: {
                    withAnimation {
                        showOnboarding = false
                    }
                })
                .transition(.scale(scale: 0.98).combined(with: .opacity))
                .zIndex(2000)
            }
        }
    }
}
