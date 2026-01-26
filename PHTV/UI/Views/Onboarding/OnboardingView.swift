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
        .padding(24)
        .frame(width: OnboardingStyle.cardWidth, height: OnboardingStyle.cardHeight)
        .frame(width: OnboardingStyle.containerWidth, height: OnboardingStyle.containerHeight)
    }

    private var header: some View {
        HStack(spacing: 12) {
            OnboardingAppBadge()

            VStack(alignment: .leading, spacing: 1) {
                Text("PHTV")
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                Text("Thiết lập nhanh")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(stepLabel)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)

                OnboardingProgressBar(currentStep: currentStep, totalSteps: totalSteps)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                if currentStep > 0 {
                    Button("Quay lại") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentStep -= 1
                        }
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .buttonStyle(OnboardingSecondaryButtonStyle())
                } else {
                    Spacer().frame(width: 80)
                }

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentStep += 1
                    }
                }) {
                    HStack(spacing: 6) {
                        Text(currentStep == 0 ? "Bắt đầu" : "Tiếp tục")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
        }
    }
}

// MARK: - Visual Styles

struct OnboardingCardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        PHTVRoundedRect(cornerRadius: OnboardingStyle.cardCornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                PHTVRoundedRect(cornerRadius: OnboardingStyle.cardCornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 0.5)
            )
    }
}

struct OnboardingSurface: View {
    let cornerRadius: CGFloat
    let fillColor: Color
    let strokeColor: Color

    var body: some View {
        PHTVRoundedRect(cornerRadius: cornerRadius, style: .continuous)
            .fill(fillColor)
            .overlay(
                PHTVRoundedRect(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(strokeColor, lineWidth: 0.5)
            )
    }
}

struct OnboardingAppBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let image = NSApp.applicationIconImage ?? NSImage()
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 36, height: 36)
            .clipShape(PHTVRoundedRect(cornerRadius: 8, style: .continuous))
    }
}

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.2))
                    .frame(width: 20, height: 5)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentStep)
    }
}

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .foregroundColor(.white)
            .background(Color.accentColor)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct OnboardingSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundColor(.secondary)
            .background(
                Capsule()
                    .fill(Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.5 : 0.8))
            )
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct OnboardingStepHeader: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            OnboardingIconBadge(symbol: icon)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, OnboardingStyle.contentHorizontalPadding)
        .padding(.top, 6)
    }
}

struct OnboardingIconBadge: View {
    let symbol: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            PHTVRoundedRect(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    PHTVRoundedRect(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 0.5)
                )
                .frame(width: 40, height: 40)

            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentColor)
        }
    }
}

// MARK: - Reusable Components

struct OnboardingHighlightCard: View {
    let icon: String
    let title: String
    let subtitle: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            Text(subtitle)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            OnboardingSurface(
                cornerRadius: 12,
                fillColor: Color(nsColor: .controlBackgroundColor),
                strokeColor: Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
            )
        )
    }
}

struct OptionCard: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))

                    Text(description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .accentColor : Color.gray.opacity(0.3))
            }
            .padding(14)
            .background(
                OnboardingSurface(
                    cornerRadius: 12,
                    fillColor: Color(nsColor: .controlBackgroundColor),
                    strokeColor: isSelected ? Color.accentColor.opacity(0.5) : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
                )
            )
        }
        .buttonStyle(.plain)
    }
}

struct FeatureToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Icon - centered vertically
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 26, height: 26)

            // Text content - fixed height for consistency
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Text(description)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(height: 36, alignment: .leading)

            Spacer(minLength: 4)

            // Toggle - centered vertically
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: 58)
        .background(
            OnboardingSurface(
                cornerRadius: 10,
                fillColor: Color(nsColor: .controlBackgroundColor),
                strokeColor: Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
            )
        )
    }
}

struct OnboardingChecklistCard: View {
    let title: String
    let subtitle: String
    let items: [String]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Text(subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }

            ForEach(items, id: \.self) { item in
                OnboardingChecklistItem(text: item)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            OnboardingSurface(
                cornerRadius: 12,
                fillColor: Color(nsColor: .controlBackgroundColor),
                strokeColor: Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
            )
        )
    }
}

struct OnboardingChecklistItem: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.red)
            Text(text)
                .font(.system(size: 11, design: .rounded))
        }
    }
}

struct OnboardingStatusCard: View {
    let icon: String
    let title: String
    let description: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Text(description)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            OnboardingSurface(
                cornerRadius: 12,
                fillColor: tint.opacity(0.08),
                strokeColor: tint.opacity(0.2)
            )
        )
    }
}

struct OnboardingNumberedRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.accentColor)
                .frame(width: 16, height: 16)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                )

            Text(text)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Steps

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 4)

            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)

                Text("Chào mừng đến với PHTV")
                    .font(.system(size: 26, weight: .bold, design: .rounded))

                Text("Thiết lập nhanh trong chưa đầy 1 phút để tối ưu trải nghiệm gõ tiếng Việt mượt mà và ổn định.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 36)
            }

            HStack(spacing: 10) {
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
            .padding(.horizontal, 28)

            Text("Bạn có thể thay đổi mọi thiết lập trong Cài đặt bất cứ lúc nào.")
                .font(.system(size: 11, design: .rounded))
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

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 12) {
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
                        icon: "textformat.abc",
                        title: "Chính tả mới",
                        description: "Đặt dấu oà, uý thay vì òa, úy.",
                        isOn: $appState.useModernOrthography
                    )

                    FeatureToggleRow(
                        icon: "textformat.size.larger",
                        title: "Viết hoa chữ cái đầu",
                        description: "Tự viết hoa sau dấu chấm câu.",
                        isOn: $appState.upperCaseFirstChar
                    )

                    FeatureToggleRow(
                        icon: "hare.fill",
                        title: "Gõ nhanh (Quick Telex)",
                        description: "Rút gọn tổ hợp phím khi gõ Telex.",
                        isOn: $appState.quickTelex
                    )

                    FeatureToggleRow(
                        icon: "character.bubble.fill",
                        title: "Giữ nguyên từ tiếng Anh",
                        description: "Không biến đổi từ tiếng Anh khi gõ.",
                        isOn: $appState.autoRestoreEnglishWord
                    )
                }
                .padding(.horizontal, OnboardingStyle.contentHorizontalPadding)
                .padding(.bottom, 12)
            }

            Text("Bạn có thể điều chỉnh thêm trong Cài đặt sau.")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
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
                        OnboardingSurface(
                            cornerRadius: 14,
                            fillColor: Color(nsColor: .controlBackgroundColor),
                            strokeColor: Color.black.opacity(0.1)
                        )
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
        VStack(spacing: 20) {
            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 160, height: 160)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.accentColor)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }

            VStack(spacing: 8) {
                Text("Hoàn tất thiết lập")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("PHTV đã sẵn sàng. Bạn có thể mở Cài đặt để tinh chỉnh thêm bất cứ lúc nào.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 36)

            Spacer()

            Button(action: {
                UserDefaults.standard.set(true, forKey: UserDefaultsKey.onboardingCompleted)
                onFinish()
            }) {
                Text("Bắt đầu sử dụng")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(width: 180)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .padding(.bottom, 28)
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
