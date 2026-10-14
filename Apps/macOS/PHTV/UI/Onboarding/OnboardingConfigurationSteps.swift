import SwiftUI

struct InputMethodStepView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var settings = appState
        VStack(spacing: 16) {
            OnboardingStepHeader(
                title: "Chọn kiểu gõ",
                subtitle: "Chọn cách gõ bạn quen dùng.",
                icon: "keyboard"
            )
            Form {
                Section("Phương pháp gõ") {
                    Picker("Phương pháp gõ", selection: $settings.inputMethod) {
                        ForEach(InputMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .accessibilityLabel("Phương pháp gõ")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }
}

struct BasicFeaturesStepView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var settings = appState
        VStack(spacing: 16) {
            OnboardingStepHeader(
                title: "Tuỳ chỉnh cách gõ",
                subtitle: "Bạn có thể thay đổi các lựa chọn này trong Cài đặt.",
                icon: "slider.horizontal.3"
            )
            Form {
                Section {
                    Toggle("Gõ tắt", isOn: $settings.useMacro)
                    Toggle("Ghi nhớ chế độ theo ứng dụng", isOn: $settings.useSmartSwitchKey)
                    Toggle("Chính tả mới (oà, uý)", isOn: $settings.useModernOrthography)
                    Toggle("Viết hoa đầu câu", isOn: $settings.upperCaseFirstChar)
                    Toggle("Gõ nhanh Telex", isOn: $settings.quickTelex)
                    Toggle("Tự động khôi phục từ", isOn: $settings.autoRestoreEnglishWord)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }
}
