//
//  OnboardingView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    var onDismiss: () -> Void
    @State private var currentStep = 0
    
    // Steps definition
    private let totalSteps = 6
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Progress Indicator
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) {
                    index in
                    Capsule()
                        .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                        .animation(.spring(), value: currentStep)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 40)
            .padding(.bottom, 10)
            
            // MARK: - Content Area
            ZStack {
                switch currentStep {
                case 0:
                    WelcomeStepView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 1:
                    SystemSettingsStepView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 2:
                    InputMethodStepView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 3:
                    BasicFeaturesStepView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 4:
                    AccessibilityStepView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case 5:
                    CompletionStepView(onFinish: {
                        onDismiss()
                    })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // MARK: - Bottom Navigation Bar
            if currentStep < totalSteps - 1 {
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
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                        } else {
                            Spacer().frame(width: 60)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        }) {
                            HStack {
                                Text(currentStep == 0 ? "Bắt đầu" : "Tiếp tục")
                                Image(systemName: "arrow.right")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.defaultAction)
                        .padding(.trailing, 20)
                    }
                    .frame(height: 60)
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: 700, height: 500)
    }
}

// MARK: - Reusable Components

struct OptionCard: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 15) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .accentColor : .gray.opacity(0.5))
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: icon)
                        Text(title)
                            .font(.headline)
                    }
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
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
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .frame(width: 32)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Steps

struct SystemSettingsStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Cấu hình Hệ thống")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Tắt các tính năng tự động của macOS để tránh xung đột")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Vui lòng tắt các mục sau:")
                            .font(.headline)
                        
                        Group {
                            HStack {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                Text("Correct spelling automatically")
                            }
                            HStack {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                Text("Capitalize words automatically")
                            }
                            HStack {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                Text("Show inline predictive text")
                            }
                            HStack {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                Text("Add period with double-space")
                            }
                            HStack {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                Text("Use smart quotes and dashes")
                            }
                        }
                        .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image("onboarding_system_settings")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 180)
                        .cornerRadius(8)
                        .shadow(radius: 3)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                
                Button("Mở Cài đặt Bàn phím") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .shadow(radius: 10)
            
            VStack(spacing: 16) {
                Text("Chào mừng đến với PHTV")
                    .font(.system(size: 32, weight: .bold))
                
                Text("Bộ gõ tiếng Việt hiện đại, mượt mà và ổn định nhất cho macOS.\nTrải nghiệm gõ không giới hạn ngay bây giờ.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}

struct InputMethodStepView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Chọn kiểu gõ")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Bạn quen thuộc với kiểu gõ nào nhất?")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            VStack(spacing: 16) {
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
                    description: "Giản lược, hạn chế gõ sai dấu tiếng Anh.",
                    icon: "wand.and.stars",
                    isSelected: appState.inputMethod == .simpleTelex1
                ) {
                    appState.inputMethod = .simpleTelex1
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

struct BasicFeaturesStepView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Tính năng cơ bản")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Tùy chỉnh trải nghiệm gõ của bạn")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            ScrollView {
                VStack(spacing: 12) {
                    FeatureToggleRow(
                        icon: "text.magnifyingglass",
                        title: "Kiểm tra chính tả",
                        description: "Tự động phát hiện và ngăn chặn gõ sai từ tiếng Việt.",
                        isOn: $appState.checkSpelling
                    )
                    
                    FeatureToggleRow(
                        icon: "bolt.fill",
                        title: "Gõ tắt (Macro)",
                        description: "Sử dụng bảng gõ tắt để tăng tốc độ nhập liệu.",
                        isOn: $appState.useMacro
                    )
                    
                    FeatureToggleRow(
                        icon: "arrow.2.squarepath",
                        title: "Chuyển chế độ thông minh",
                        description: "Tự động ghi nhớ kiểu gõ cho từng ứng dụng.",
                        isOn: $appState.useSmartSwitchKey
                    )
                    
                    FeatureToggleRow(
                        icon: "globe",
                        title: "Phụ âm ngoài (Z, F, W, J)",
                        description: "Cho phép gõ Z, F, W, J như phụ âm cuối.",
                        isOn: $appState.allowConsonantZFWJ
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
        }
    }
}

struct AccessibilityStepView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 8) {
                Text("Cấp quyền truy cập")
                    .font(.title)
                    .fontWeight(.bold)
                Text("PHTV cần quyền Accessibility để hoạt động.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            VStack(spacing: 20) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 60))
                    .foregroundColor(appState.hasAccessibilityPermission ? .green : .orange)
                    .scaleEffect(appState.hasAccessibilityPermission ? 1.1 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: appState.hasAccessibilityPermission)
                
                if appState.hasAccessibilityPermission {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Đã cấp quyền thành công!")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Hướng dẫn:")
                            .font(.headline)
                        HStack(alignment: .top) {
                            Text("1.")
                            Text("Nhấn nút bên dưới để mở Cài đặt Hệ thống.")
                        }
                        HStack(alignment: .top) {
                            Text("2.")
                            Text("Tìm và bật công tắc cho **PHTV**.")
                        }
                        HStack(alignment: .top) {
                            Text("3.")
                            Text("Nếu đã bật, hãy tắt đi và bật lại.")
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                    
                    Button("Mở Cài đặt Quyền riêng tư") {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 40)
            
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
        VStack(spacing: 30) {
            Spacer() 
            
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 200, height: 200)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
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
            
            VStack(spacing: 16) {
                Text("Hoàn tất!")
                    .font(.system(size: 32, weight: .bold))
                
                Text("PHTV đã sẵn sàng phục vụ bạn.\nHãy tận hưởng trải nghiệm gõ tiếng Việt tuyệt vời.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            Spacer() 
            
            Button(action: {
                UserDefaults.standard.set(true, forKey: UserDefaultsKey.onboardingCompleted)
                onFinish()
            }) {
                Text("Bắt đầu sử dụng ngay")
                    .font(.headline)
                    .frame(width: 200)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 5)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 50)
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
                .blur(radius: showOnboarding ? 5 : 0)
                .disabled(showOnboarding)
            
            if showOnboarding {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                OnboardingView(onDismiss: {
                    withAnimation {
                        showOnboarding = false
                    }
                })
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2000)
            }
        }
    }
}
