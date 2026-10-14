//
//  OnboardingView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import Observation

private enum OnboardingStyle {
    static let cardWidth: CGFloat = 740
    static let cardHeight: CGFloat = 560
    static let contentHorizontalPadding: CGFloat = 36
}

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onDismiss: () -> Void
    @AppStorage(UserDefaultsKey.onboardingCompleted) private var hasCompletedOnboarding = false
    @State private var currentStep: Int

    /// Index of the "Quyền truy cập" step — permission guidance can open the
    /// onboarding directly here so users who lost a permission don't have to
    /// click through the whole tour again.
    static let permissionStepIndex = 4

    init(onDismiss: @escaping () -> Void, initialStep: Int = 0) {
        self.onDismiss = onDismiss
        self._currentStep = State(initialValue: initialStep)
    }

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

    private var maxStep: Int {
        totalSteps - 1
    }

    private var safeStep: Int {
        min(max(currentStep, 0), maxStep)
    }

    private var stepLabel: String {
        let index = min(safeStep, stepTitles.count - 1)
        return "Bước \(safeStep + 1)/\(totalSteps) · \(stepTitles[index])"
    }

    private var stepTransition: AnyTransition {
        reduceMotion ? .identity : .opacity
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ZStack {
                switch safeStep {
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
                    AccessibilityStepView(onPermissionsReady: {
                        advanceAfterPermissionsGranted()
                    })
                    .transition(stepTransition)
                case 5:
                    CompletionStepView()
                    .transition(stepTransition)
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .padding(.bottom, 12)

            footer
        }
        .frame(width: OnboardingStyle.cardWidth, height: OnboardingStyle.cardHeight)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Thiết lập PHTV")
                .font(.headline)

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(stepLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                OnboardingProgressBar(currentStep: safeStep, totalSteps: totalSteps)
            }

            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 16, height: 16)
            }
            .adaptiveBorderedButtonStyle()
            .buttonBorderShape(.circle)
            .keyboardShortcut(.cancelAction)
            .help("Đóng thiết lập nhanh")
            .accessibilityLabel("Đóng thiết lập nhanh")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                if safeStep > 0 {
                    Button("Quay lại") {
                        goToPreviousStep()
                    }
                    .keyboardShortcut("[", modifiers: .command)
                    .adaptiveBorderedButtonStyle()
                    .controlSize(.regular)
                } else {
                    Spacer().frame(width: 80)
                }

                Spacer()

                Button(safeStep == maxStep ? "Bắt đầu sử dụng" : (safeStep == 0 ? "Bắt đầu" : "Tiếp tục")) {
                    if safeStep == maxStep {
                        hasCompletedOnboarding = true
                        onDismiss()
                    } else {
                        goToNextStep()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
        }
    }

    private func goToPreviousStep() {
        let previousStep = max(currentStep - 1, 0)
        guard previousStep != currentStep else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            currentStep = previousStep
        }
    }

    private func goToNextStep() {
        let nextStep = min(currentStep + 1, maxStep)
        guard nextStep != currentStep else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            currentStep = nextStep
        }
    }

    /// Both permissions just got granted while the user was on the permission
    /// step: give them a moment to see the green confirmation, then move on.
    private func advanceAfterPermissionsGranted() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard currentStep == Self.permissionStepIndex else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                currentStep = Self.permissionStepIndex + 1
            }
        }
    }
}

// MARK: - Visual Styles

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

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
            .progressViewStyle(.linear)
            .frame(width: 140)
            .accessibilityLabel("Tiến trình thiết lập")
            .accessibilityValue("Bước \(currentStep + 1) trên \(totalSteps)")
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
                    .font(.system(size: 20, weight: .bold))

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
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


struct OnboardingChecklistCard: View {
    let title: String
    let subtitle: String
    let items: [String]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: 11))
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
                .font(.system(size: 11))
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
                    .font(.system(size: 13, weight: .semibold))

                Text(description)
                    .font(.system(size: 11))
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
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.accentColor)
                .frame(width: 16, height: 16)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                )

            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct OnboardingPermissionStateRow: View {
    let title: String
    let detail: String
    let granted: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(granted ? .green : .orange)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))

                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            OnboardingSurface(
                cornerRadius: 10,
                fillColor: Color(nsColor: .controlBackgroundColor),
                strokeColor: Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
            )
        )
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
                    .font(.system(size: 26, weight: .bold))

                Text("Chọn kiểu gõ và cấp quyền để bắt đầu.")
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 36)
            }

            Spacer()
        }
    }
}

struct SystemSettingsStepView: View {
    @Environment(\.openURL) private var openURL
    @State private var showZoom = false

    var body: some View {
        VStack(spacing: 18) {
            OnboardingStepHeader(
                title: "Cấu hình hệ thống",
                subtitle: "Điều chỉnh các mục này nếu bạn gặp xung đột khi gõ",
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
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, OnboardingStyle.contentHorizontalPadding)

            Button("Mở Cài đặt Bàn phím") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard") {
                    openURL(url)
                }
            }
            .adaptiveProminentButtonStyle()
            .controlSize(.large)

            Spacer()
        }
    }
}

struct AccessibilityStepView: View {
    @Environment(AppState.self) private var appState
    /// Called once when Accessibility and the active tap become ready while
    /// this step is visible, so onboarding can advance on its own.
    var onPermissionsReady: (() -> Void)? = nil
    @State private var sawMissingPermission = false

    var body: some View {
        let runtimeHealth = appState.typingRuntimeHealth
        let permissionName = PHTVAccessibilityPermissionNaming.displayName

        VStack(spacing: 14) {
            OnboardingStepHeader(
                title: "Cấp quyền nhập liệu",
                subtitle: "PHTV cần quyền \(permissionName) để bắt phím ổn định",
                icon: "hand.raised.fill"
            )

            VStack(spacing: 12) {
                OnboardingPermissionStateRow(
                    title: permissionName,
                    detail: "Cho phép PHTV thao tác với ô nhập liệu và xử lý bàn phím.",
                    granted: runtimeHealth.hasAccessibilityPermission
                )

                permissionGuidanceContent(for: runtimeHealth)

                if let actionTitle = permissionActionTitle(for: runtimeHealth.phase) {
                    Button(actionTitle) {
                        AppDelegate.current()?.continuePermissionGuidanceIfNeeded(
                            forceOpenSystemSettings: true
                        )
                    }
                    .adaptiveProminentButtonStyle()
                    .controlSize(.large)
                }

                if runtimeHealth.phase == .accessibilityRequired {
                    Text("Bạn có thể tiếp tục và cấp quyền sau trong Cài đặt.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, OnboardingStyle.contentHorizontalPadding)

            Spacer()
        }
        .task {
            refreshPermissionState()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                refreshPermissionState()
            }
        }
    }

    @ViewBuilder
    private func permissionGuidanceContent(for runtimeHealth: PHTVTypingRuntimeHealthSnapshot) -> some View {
        let permissionName = PHTVAccessibilityPermissionNaming.displayName
        switch runtimeHealth.phase {
        case .ready:
            OnboardingStatusCard(
                icon: "checkmark.seal.fill",
                title: "PHTV đã sẵn sàng",
                description: "Quyền đã được cấp và bộ gõ đã sẵn sàng hoạt động.",
                tint: .green
            )
        case .accessibilityRequired:
            guidancePanel(
                title: "Cấp quyền \(permissionName)",
                rows: [
                    "Nhấn nút bên dưới để PHTV làm mới mục quyền cũ rồi mở Cài đặt Hệ thống.",
                    "Trong Quyền riêng tư & Bảo mật > \(permissionName), bật PHTV.",
                    "Sau khi macOS nhận quyền, PHTV sẽ tự khởi tạo bộ gõ."
                ]
            )
        case .relaunchPending:
            OnboardingStatusCard(
                icon: "arrow.clockwise.circle.fill",
                title: "PHTV đang tự khởi động lại",
                description: "macOS đã nhận quyền. PHTV đang chờ mở lại để bộ gõ hoạt động ổn định.",
                tint: .blue
            )

            guidancePanel(
                title: "Trong lúc chờ",
                rows: [
                    "Giữ nguyên cửa sổ cài đặt trong vài giây để macOS hoàn tất áp dụng quyền.",
                    "PHTV sẽ tự mở lại. Nếu chưa thấy, hãy mở lại PHTV một lần.",
                    "Khi PHTV mở lại, trạng thái sẽ tự chuyển sang sẵn sàng."
                ]
            )
        case .waitingForEventTap:
            OnboardingStatusCard(
                icon: "clock.badge.exclamationmark.fill",
                title: "Đang hoàn tất khởi tạo",
                description: "Quyền đã được cấp, nhưng PHTV vẫn đang chờ bộ gõ hoạt động.",
                tint: .yellow
            )

            guidancePanel(
                title: "Nếu chưa hoạt động",
                rows: [
                    "Nhấn Thử lại ngay để PHTV tự kiểm tra và khởi tạo lại bộ gõ.",
                    "Nếu vừa cấp quyền, hãy chờ vài giây để macOS áp dụng thay đổi.",
                    "Nếu vẫn chưa gõ được, hãy đóng rồi mở lại PHTV một lần."
                ]
            )
        }
    }

    private func guidancePanel(title: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                OnboardingNumberedRow(number: "\(index + 1)", text: row)
            }
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
    }

    private func permissionActionTitle(for phase: PHTVTypingRuntimePhase) -> String? {
        switch phase {
        case .accessibilityRequired:
            return "Mở \(PHTVAccessibilityPermissionNaming.displayName)"
        case .waitingForEventTap:
            return "Thử lại ngay"
        case .ready, .relaunchPending:
            return nil
        }
    }

    private func refreshPermissionState() {
        let permissionState = appState.checkAccessibilityPermission()

        if permissionState != .ready {
            sawMissingPermission = true
            AppDelegate.current()?.continuePermissionGuidanceIfNeeded()
        } else if sawMissingPermission {
            sawMissingPermission = false
            onPermissionsReady?()
        }
    }
}

// MARK: - Onboarding Container

struct OnboardingContainer<Content: View>: View {
    @Binding var showOnboarding: Bool
    var initialStep: Int
    let content: Content

    init(showOnboarding: Binding<Bool>,
         initialStep: Int = 0,
         @ViewBuilder content: () -> Content) {
        self._showOnboarding = showOnboarding
        self.initialStep = initialStep
        self.content = content()
    }

    var body: some View {
        content
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(
                    onDismiss: { showOnboarding = false },
                    initialStep: initialStep
                )
            }
    }
}
