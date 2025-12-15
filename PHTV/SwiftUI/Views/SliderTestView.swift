//
//  SliderTestView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AudioToolbox
import AppKit

struct SliderTestView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Test Sliders Functionality")
                .font(.title)
            
            // Test Beep Volume
            VStack(spacing: 10) {
                HStack {
                    Text("Beep Volume: \(String(format: "%.0f%%", appState.beepVolume * 100))")
                    Spacer()
                    Button("Test Beep") {
                        if appState.beepVolume > 0.0 {
                            BeepManager.shared.play(volume: appState.beepVolume)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Slider(value: $appState.beepVolume, in: 0...1, step: 0.01)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Font size test removed
            
            // Test Menu Bar Icon Size
            VStack(spacing: 10) {
                HStack {
                    Text("Menu Bar Icon: \(String(format: "%.0f px", appState.menuBarIconSize))")
                    Spacer()
                }
                
                Text("Change this and check menu bar icon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Slider(value: $appState.menuBarIconSize, in: 12...20, step: 1)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SliderTestView()
        .environmentObject(AppState.shared)
}
