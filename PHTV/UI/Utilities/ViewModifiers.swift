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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            content
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .settingsGlassEffect(cornerRadius: 12)
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
                        .settingsGlassEffect(cornerRadius: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
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

// MARK: - Settings Glass Effect

@available(macOS 26.0, *)
private struct SettingsGlassEffectModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
        } else {
            content.glassEffect(in: .rect(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    /// Applies glassEffect when available and reduce transparency is off
    @ViewBuilder
    func settingsGlassEffect(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            modifier(SettingsGlassEffectModifier(cornerRadius: cornerRadius))
        } else {
            self
        }
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
                .opacity(configuration.isPressed ? 0.85 : 1.0)
        } else {
            configuration.label
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .buttonStyle(.borderedProminent)
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
                .opacity(configuration.isPressed ? 0.85 : 1.0)
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

// MARK: - Adaptive Button Styles

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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(pillBaseFill)
                    .overlay(
                        Capsule()
                            .fill(color.opacity(colorScheme == .light ? 0.12 : 0.18))
                    )
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(colorScheme == .light ? 0.35 : 0.45), lineWidth: 1)
            )
            .foregroundStyle(color)
            .accessibilityLabel(Text(text))
    }

    private var pillBaseFill: Color {
        if colorScheme == .light {
            return Color(NSColor.controlBackgroundColor).opacity(0.9)
        }
        return Color(NSColor.windowBackgroundColor).opacity(0.25)
    }
}

struct SettingsHeaderView<Trailing: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    var accent: Color = .accentColor
    let trailing: Trailing
    @Environment(\.colorScheme) private var colorScheme

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
            iconTile

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 19, weight: .semibold))
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
        .shadow(color: headerShadowColor, radius: 6, x: 0, y: 3)
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(iconBackground)
            RoundedRectangle(cornerRadius: 12)
                .stroke(iconBorderColor, lineWidth: 1)
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: 48, height: 48)
    }

    @ViewBuilder
    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(headerGradient)
            .settingsGlassEffect(cornerRadius: 14)
    }

    private var headerBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(borderColor, lineWidth: 1)
    }

    private var headerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(NSColor.windowBackgroundColor).opacity(colorScheme == .dark ? 0.35 : 0.92),
                Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.75 : 0.86),
                Color.accentColor.opacity(colorScheme == .dark ? 0.1 : 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.16)
    }

    private var iconBackground: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(colorScheme == .dark ? 0.28 : 0.2),
                accent.opacity(colorScheme == .dark ? 0.16 : 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconBorderColor: Color {
        accent.opacity(colorScheme == .dark ? 0.35 : 0.4)
    }

    private var headerShadowColor: Color {
        colorScheme == .dark ? .clear : .black.opacity(0.08)
    }

    
}

// MARK: - Settings View Background

/// Applies consistent background for settings views
struct SettingsViewBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(NSColor.windowBackgroundColor).opacity(colorScheme == .light ? 0.98 : 1.0),
                            Color(NSColor.controlBackgroundColor).opacity(colorScheme == .light ? 0.96 : 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [
                            Color.accentColor.opacity(colorScheme == .light ? 0.06 : 0.12),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 520
                    )
                }
                .ignoresSafeArea()
            )
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
