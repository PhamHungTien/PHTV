//
//  PreviewHelpers.swift
//  PHTV
//
//  Preview helpers for SwiftUI development
//  Created by Phạm Hùng Tiến on 2026.
//

import SwiftUI

// MARK: - Preview Data
extension AppState {
    static var preview: AppState {
        let state = AppState.shared
        state.isEnabled = true
        state.checkSpelling = true
        state.useModernOrthography = true
        state.useMacro = true
        state.hasAccessibilityPermission = true
        return state
    }
    
    static var previewDisabled: AppState {
        let state = AppState.shared
        state.isEnabled = false
        state.hasAccessibilityPermission = false
        return state
    }
}

extension MacroItem {
    static var preview: [MacroItem] {
        [
            MacroItem(shortcut: "addr", expansion: "123 Đường ABC, Quận XYZ, TP. HCM"),
            MacroItem(shortcut: "email", expansion: "example@email.com"),
            MacroItem(shortcut: "phone", expansion: "0123 456 789"),
            MacroItem(shortcut: "sig", expansion: "Trân trọng,\nPhạm Hùng Tiến"),
            MacroItem(shortcut: "ty", expansion: "Cảm ơn bạn"),
        ]
    }
}

// MARK: - Preview Wrappers
struct PreviewWrapper<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .environmentObject(AppState.preview)
    }
}

// MARK: - Previews for Main Views
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode
            SettingsView()
                .environmentObject(AppState.preview)
                .previewDisplayName("Light Mode")
            
            // Dark mode
            SettingsView()
                .environmentObject(AppState.preview)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}

struct TypingSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TypingSettingsView()
                .environmentObject(AppState.preview)
                .previewDisplayName("With Permission")
            
            TypingSettingsView()
                .environmentObject(AppState.previewDisabled)
                .previewDisplayName("No Permission")
        }
    }
}

struct MacroSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MacroSettingsView()
            .environmentObject(AppState.preview)
    }
}

struct SystemSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SystemSettingsView()
            .environmentObject(AppState.preview)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}

// MARK: - Component Previews
struct PermissionWarningView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PermissionWarningView(hasPermission: false)
                .padding()
                .previewLayout(.sizeThatFits)
            
            PermissionWarningView(hasPermission: true)
                .padding()
                .preferredColorScheme(.dark)
                .previewLayout(.sizeThatFits)
        }
    }
}

struct HotkeyConfigView_Previews: PreviewProvider {
    static var previews: some View {
        HotkeyConfigView()
            .environmentObject(AppState.preview)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}

struct MacroEditorView_Previews: PreviewProvider {
    static var previews: some View {
        MacroEditorView(isPresented: .constant(true))
    }
}
