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
            // Use drawingGroup() to flatten the view hierarchy and reduce compositing
            content
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                .drawingGroup(opaque: false)
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

// MARK: - Settings Header Components

struct SettingsStatusPill: View {
    let text: String
    var color: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
            .foregroundStyle(color)
            .accessibilityLabel(Text(text))
    }
}

struct SettingsHeaderView<Trailing: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    var accent: Color = .accentColor
    let trailing: Trailing

    init(
        title: String,
        subtitle: String,
        icon: String,
        accent: Color = .accentColor,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accent = accent
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.35), accent.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accent.opacity(0.4), lineWidth: 1)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            trailing
        }
        .padding(18)
        .frame(maxWidth: 700)
        .background(headerBackground)
        .overlay(headerBorder)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.18),
                        accent.opacity(0.08),
                        Color(NSColor.controlBackgroundColor).opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var headerBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(accent.opacity(0.35), lineWidth: 1)
    }
}

// MARK: - Settings View Background

/// Visual Effect background for blur effect
/// Optimized: Uses Equatable to prevent unnecessary CALayer updates
struct VisualEffectBackground: NSViewRepresentable, Equatable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        // Performance: Disable implicit animations for property changes
        view.wantsLayer = true
        view.layer?.actions = ["contents": NSNull(), "bounds": NSNull()]
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // Only update if values changed to reduce CALayer updates
        if nsView.material != material {
            nsView.material = material
        }
        if nsView.blendingMode != blendingMode {
            nsView.blendingMode = blendingMode
        }
    }

    nonisolated static func == (lhs: VisualEffectBackground, rhs: VisualEffectBackground) -> Bool {
        lhs.material == rhs.material && lhs.blendingMode == rhs.blendingMode
    }
}

/// Applies appropriate background for settings views
/// Uses sidebar material for beautiful liquid glass effect when enabled
/// Optimized: Reads directly from UserDefaults to avoid unnecessary redraws from AppState changes
struct SettingsViewBackground: ViewModifier {
    // Read directly from UserDefaults to avoid subscribing to all AppState changes
    // Keys must match AppState: "vEnableLiquidGlassBackground" and "vSettingsBackgroundOpacity"
    @AppStorage("vEnableLiquidGlassBackground") private var enableLiquidGlass = true
    @AppStorage("vSettingsBackgroundOpacity") private var backgroundOpacity = 1.0

    func body(content: Content) -> some View {
        if enableLiquidGlass {
            content
                .scrollContentBackground(.hidden)
                .background(
                    VisualEffectBackground(
                        material: .sidebar,
                        blendingMode: .behindWindow
                    )
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()
                )
        } else {
            content
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.windowBackgroundColor))
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
