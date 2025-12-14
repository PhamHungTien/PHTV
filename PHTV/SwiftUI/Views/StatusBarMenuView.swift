//
//  StatusBarMenuView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct StatusBarMenuView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        // Language toggle
        Button {
            appState.isEnabled = true
        } label: {
            HStack {
                Image(systemName: "v.circle.fill")
                Text("Tiếng Việt")
                if appState.isEnabled {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
        .keyboardShortcut("v", modifiers: [.control, .shift])
        
        Button {
            appState.isEnabled = false
        } label: {
            HStack {
                Image(systemName: "e.circle.fill")
                Text("Tiếng Anh")
                if !appState.isEnabled {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
        
        Divider()
        
        // Input Method
        Menu {
            ForEach(InputMethod.allCases) { method in
                Button {
                    appState.inputMethod = method
                } label: {
                    HStack {
                        Text(method.rawValue)
                        if appState.inputMethod == method {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Kiểu gõ: \(appState.inputMethod.rawValue)", systemImage: "keyboard")
        }
        
        // Code Table
        Menu {
            ForEach(CodeTable.allCases) { table in
                Button {
                    appState.codeTable = table
                } label: {
                    HStack {
                        Text(table.displayName)
                        if appState.codeTable == table {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Bảng mã: \(appState.codeTable.displayName)", systemImage: "textformat")
        }
        
        Divider()
        
        // Quick toggles
        Toggle(isOn: $appState.checkSpelling) {
            Label("Kiểm tra chính tả", systemImage: "checkmark.seal")
        }
        
        Toggle(isOn: $appState.useMacro) {
            Label("Gõ tắt", systemImage: "text.badge.plus")
        }
        
        Divider()
        
        // Settings
        Button {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Label("Cài đặt...", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)
        
        Button {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
            // Switch to About tab after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NSNotification.Name("ShowAboutTab"), object: nil)
            }
        } label: {
            Label("Về PHTV...", systemImage: "info.circle")
        }
        
        Divider()
        
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Thoát PHTV", systemImage: "power")
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

#Preview {
    StatusBarMenuView()
        .environmentObject(AppState.shared)
}
