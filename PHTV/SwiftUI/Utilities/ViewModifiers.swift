//
//  ViewModifiers.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

// MARK: - Custom View Modifiers for consistent styling

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .glassEffect(in: .rect(cornerRadius: 12))
                }
        } else {
            content
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
}

struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundColor(.primary)
            .padding(.top, 8)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    func sectionHeader() -> some View {
        modifier(SectionHeaderStyle())
    }

    // Apply consistent defaults for TextField across the app
    @ViewBuilder
    func settingsTextField() -> some View {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || targetEnvironment(macCatalyst)
        if #available(iOS 15.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *) {
            self
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
        } else {
            self
                .disableAutocorrection(true)
        }
        #elseif os(macOS)
        if #available(macOS 12.0, *) {
            self
                .disableAutocorrection(true)
        } else {
            self
        }
        #else
        self
        #endif
    }

    // Rounded text area style for TextEditor and similar inputs
    func roundedTextArea() -> some View {
        self
            .padding(6)
            .background {
                if #available(macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .glassEffect(in: .rect(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
    }
}

// MARK: - Background Extension for Liquid Glass

/// Applies backgroundExtensionEffect on macOS 26+ to allow content to extend under the sidebar
struct BackgroundExtensionModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .backgroundExtensionEffect()
        } else {
            content
        }
    }
}

extension View {
    func liquidGlassBackground() -> some View {
        modifier(BackgroundExtensionModifier())
    }
}

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            configuration.label
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .buttonStyle(.glassProminent)
        } else {
            configuration.label
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(6)
                .opacity(configuration.isPressed ? 0.8 : 1.0)
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            configuration.label
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .buttonStyle(.glass)
        } else {
            configuration.label
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .foregroundColor(.primary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .opacity(configuration.isPressed ? 0.8 : 1.0)
        }
    }
}

// MARK: - Animations

extension Animation {
    static let phtv = Animation.easeInOut(duration: 0.25)
    static let phtvSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
}

// MARK: - Color Extensions

extension Color {
    static let phtvPrimary = Color.accentColor
    static let phtvSecondary = Color(NSColor.secondaryLabelColor)
    static let phtvBackground = Color(NSColor.windowBackgroundColor)
    static let phtvSurface = Color(NSColor.controlBackgroundColor)
}

// MARK: - Adaptive Button Styles for Liquid Glass

extension View {
    /// Applies glassProminent on macOS 26+, borderedProminent on older versions
    @ViewBuilder
    func adaptiveProminentButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Applies glass on macOS 26+, bordered on older versions
    @ViewBuilder
    func adaptiveBorderedButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

// MARK: - Settings View Background

/// Visual Effect background for blur effect
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// Applies appropriate background for settings views
/// On macOS 26+: Uses Liquid Glass effects
/// On older versions: Uses blurred window background
struct SettingsViewBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .scrollContentBackground(.hidden)
                .background(.clear)
        } else {
            content
                .scrollContentBackground(.hidden)
                .background(
                    VisualEffectBackground(
                        material: .sidebar,
                        blendingMode: .behindWindow
                    )
                )
        }
    }
}

extension View {
    /// Applies appropriate background for settings detail views
    func settingsBackground() -> some View {
        modifier(SettingsViewBackground())
    }

    /// Conditionally applies searchable modifier (macOS 12+)
    /// On macOS 11, search is not available - the view is returned unchanged
    @ViewBuilder
    func conditionalSearchable(text: Binding<String>, prompt: String) -> some View {
        if #available(macOS 12.0, *) {
            self.searchable(text: text, placement: .sidebar, prompt: prompt)
        } else {
            self
        }
    }

    /// Compatible foregroundStyle - uses foregroundColor on macOS 11
    @ViewBuilder
    func compatForegroundStyle<S: ShapeStyle>(_ style: S) -> some View {
        if #available(macOS 12.0, *) {
            self.foregroundStyle(style)
        } else {
            if let color = style as? Color {
                self.foregroundColor(color)
            } else {
                self
            }
        }
    }

    /// Compatible foregroundStyle for HierarchicalShapeStyle
    @ViewBuilder
    func compatForegroundPrimary() -> some View {
        if #available(macOS 12.0, *) {
            self.foregroundStyle(.primary)
        } else {
            self.foregroundColor(.primary)
        }
    }

    @ViewBuilder
    func compatForegroundSecondary() -> some View {
        if #available(macOS 12.0, *) {
            self.foregroundStyle(.secondary)
        } else {
            self.foregroundColor(.secondary)
        }
    }
}
