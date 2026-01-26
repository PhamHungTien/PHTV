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
                    PHTVRoundedRect(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .settingsGlassEffect(cornerRadius: 12)
                }
        } else {
            // Use drawingGroup() to flatten the view hierarchy and reduce compositing
            content
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
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

// MARK: - Shape Utilities

struct PHTVRoundedRect: InsettableShape {
    var cornerRadius: CGFloat
    var style: RoundedCornerStyle = .continuous
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> PHTVRoundedRect {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let effectiveRadius = max(0, cornerRadius - insetAmount)

        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
            return ConcentricRectangle
                .rect(corners: .fixed(effectiveRadius), isUniform: true)
                .path(in: insetRect)
        } else {
            return RoundedRectangle(cornerRadius: effectiveRadius, style: style)
                .path(in: insetRect)
        }
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
                    PHTVRoundedRect(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .settingsGlassEffect(cornerRadius: 8)
                        .overlay(
                            PHTVRoundedRect(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                } else {
                    PHTVRoundedRect(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            PHTVRoundedRect(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
    }
}

// MARK: - Settings Glass Effect (disabled - using simple materials instead)

extension View {
    /// Glass effect disabled - returns self unchanged
    func settingsGlassEffect(cornerRadius: CGFloat) -> some View {
        self
    }

    /// Glass effect disabled - returns self unchanged
    func settingsGlassEffect<S: Shape>(in shape: S) -> some View {
        self
    }

    /// Interactive glass effect disabled - returns self unchanged
    func settingsInteractiveGlassEffect(cornerRadius: CGFloat) -> some View {
        self
    }

    /// Tinted glass effect disabled - returns self unchanged
    func settingsTintedGlassEffect(cornerRadius: CGFloat, tint: Color) -> some View {
        self
    }
}

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.5 : 0.6))
            .foregroundColor(.primary)
            .cornerRadius(6)
            .overlay(
                PHTVRoundedRect(cornerRadius: 6)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Liquid Glass Pill Button Style (macOS 26+)

struct GlassPillButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    var tint: Color = .accentColor
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? tint.opacity(colorScheme == .dark ? 0.2 : 0.15) : Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.5 : 0.6))
            )
            .foregroundStyle(isSelected ? tint : .secondary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? tint.opacity(colorScheme == .dark ? 0.3 : 0.25) : Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Animations

extension Animation {
    static let phtv = Animation.easeInOut(duration: 0.25)
    static let phtvSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)

    // macOS 26+ animations
    @available(macOS 26.0, *)
    static let phtvBouncy = Animation.bouncy(duration: 0.4, extraBounce: 0.15)

    @available(macOS 26.0, *)
    static let phtvSnappy = Animation.snappy(duration: 0.3)

    // Glass morphing animation - smoother transitions
    static let phtvMorph = Animation.spring(response: 0.35, dampingFraction: 0.85)
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
    /// Uses borderedProminent button style (no glass)
    func adaptiveProminentButtonStyle() -> some View {
        self.buttonStyle(.borderedProminent)
    }

    /// Uses bordered button style (no glass)
    func adaptiveBorderedButtonStyle() -> some View {
        self.buttonStyle(.bordered)
    }
}

// MARK: - Settings Header Components

struct SettingsStatusPill: View {
    let text: String
    var color: Color = .accentColor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(pillBackground)
            .overlay(pillBorder)
            .foregroundStyle(color)
            .accessibilityLabel(Text(text))
    }

    @ViewBuilder
    private var pillBackground: some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            Capsule()
                .fill(.ultraThinMaterial)
                .settingsGlassEffect(in: Capsule())
                .overlay(
                    Capsule()
                        .fill(color.opacity(colorScheme == .light ? 0.12 : 0.18))
                )
        } else {
            Capsule()
                .fill(pillBaseFill)
                .overlay(
                    Capsule()
                        .fill(color.opacity(colorScheme == .light ? 0.12 : 0.18))
                )
        }
    }

    private var pillBorder: some View {
        Capsule()
            .stroke(color.opacity(colorScheme == .light ? 0.35 : 0.45), lineWidth: 1)
    }

    private var pillBaseFill: Color {
        if colorScheme == .light {
            return Color(NSColor.controlBackgroundColor).opacity(0.9)
        }
        return Color(NSColor.windowBackgroundColor).opacity(0.25)
    }
}

struct SettingsIconTile<Content: View>: View {
    let color: Color
    var size: CGFloat = 36
    var cornerRadius: CGFloat = 8
    let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    init(
        color: Color,
        size: CGFloat = 36,
        cornerRadius: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.color = color
        self.size = size
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        // Just the content with color - no background
        content
            .frame(width: size, height: size)
    }
}

struct SettingsHeaderView<Trailing: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    var accent: Color = .accentColor
    let trailing: Trailing
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
    }

    private var iconTile: some View {
        Image(systemName: icon)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(accent)
            .frame(width: 48, height: 48)
    }

    @ViewBuilder
    private var headerBackground: some View {
        // Simple material background - no glass effect
        if #available(macOS 12.0, *) {
            PHTVRoundedRect(cornerRadius: 14)
                .fill(.regularMaterial)
        } else {
            PHTVRoundedRect(cornerRadius: 14)
                .fill(headerGradient)
        }
    }

    private var headerBorder: some View {
        PHTVRoundedRect(cornerRadius: 14)
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
        return colorScheme == .dark ? .clear : .black.opacity(0.08)
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
                backgroundLayer
            )
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        let base = ZStack {
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

            if #available(macOS 12.0, *) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(colorScheme == .light ? 0.6 : 0.25)
            }
        }
        .ignoresSafeArea()

        if #available(macOS 26.0, *) {
            GlassEffectContainer {
                base
                    .backgroundExtensionEffect()
            }
        } else {
            base
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

    /// Groups glass elements to align Liquid Glass rendering when available.
    @ViewBuilder
    func settingsGlassContainer() -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer {
                self
            }
        } else {
            self
        }
    }

    /// Groups glass elements with custom spacing for morphing animations.
    @ViewBuilder
    func settingsGlassContainer(spacing: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                self
            }
        } else {
            self
        }
    }

    /// Applies glassEffectID for morphing transitions between elements.
    @ViewBuilder
    func settingsGlassID<ID: Hashable & Sendable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

// MARK: - Tab Indicator

/// A morphing tab indicator with matchedGeometryEffect
struct LiquidGlassTabIndicator: View {
    let isSelected: Bool
    let cornerRadius: CGFloat
    let namespace: Namespace.ID
    let id: String

    @Environment(\.colorScheme) private var colorScheme

    init(
        isSelected: Bool,
        cornerRadius: CGFloat = 8,
        namespace: Namespace.ID,
        id: String = "tabIndicator"
    ) {
        self.isSelected = isSelected
        self.cornerRadius = cornerRadius
        self.namespace = namespace
        self.id = id
    }

    var body: some View {
        if isSelected {
            PHTVRoundedRect(cornerRadius: cornerRadius)
                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.15))
                .overlay(
                    PHTVRoundedRect(cornerRadius: cornerRadius)
                        .stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                )
                .matchedGeometryEffect(id: id, in: namespace)
        }
    }
}

// MARK: - Floating Glass Card (macOS 26+)

/// A floating card container with Liquid Glass effect
struct FloatingGlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background {
                // Simple material background - no glass effect
                if #available(macOS 12.0, *) {
                    PHTVRoundedRect(cornerRadius: cornerRadius)
                        .fill(.regularMaterial)
                } else {
                    PHTVRoundedRect(cornerRadius: cornerRadius)
                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.92))
                }
            }
            .overlay(
                PHTVRoundedRect(cornerRadius: cornerRadius)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.08), lineWidth: 1)
            )
    }
}

// MARK: - Glass Close Button (macOS 26+)

/// A circular close button with Liquid Glass effect
struct GlassCloseButton: View {
    let action: () -> Void
    var size: CGFloat = 28
    var iconSize: CGFloat = 11

    @State private var isHovering = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(isHovering ? 0.25 : 0.15))
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(isHovering ? 0.35 : 0.2), lineWidth: 1)
                    )
                Image(systemName: "xmark")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(.red)
                    .scaleEffect(isHovering ? 1.1 : 1.0)
            }
            .frame(width: size, height: size)
            .animation(.easeOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Glass Segmented Control (macOS 26+)

/// A segmented control with Liquid Glass effect and morphing selection
struct GlassSegmentedControl<SelectionValue: Hashable, Content: View>: View {
    @Binding var selection: SelectionValue
    let content: Content

    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            GlassEffectContainer(spacing: 8) {
                content
            }
        } else {
            HStack(spacing: 4) {
                content
            }
            .padding(4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(10)
        }
    }
}

// MARK: - Glass Segmented Picker (macOS 26+)

/// A picker that uses Liquid Glass morphing effect for segment selection
struct GlassSegmentedPicker<SelectionValue: Hashable & CaseIterable & Identifiable, Label: View>: View
where SelectionValue.AllCases: RandomAccessCollection {
    @Binding var selection: SelectionValue
    let label: (SelectionValue) -> Label

    @Namespace private var pickerNamespace
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    init(
        selection: Binding<SelectionValue>,
        @ViewBuilder label: @escaping (SelectionValue) -> Label
    ) {
        self._selection = selection
        self.label = label
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(SelectionValue.allCases)) { item in
                segmentButton(for: item)
            }
        }
        .padding(4)
        .background(Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.5 : 0.6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func segmentButton(for item: SelectionValue) -> some View {
        let isSelected = selection == item

        Button {
            withAnimation(.phtvMorph) {
                selection = item
            }
        } label: {
            label(item)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background {
                    if isSelected {
                        PHTVRoundedRect(cornerRadius: 7)
                            .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.15))
                            .overlay(
                                PHTVRoundedRect(cornerRadius: 7)
                                    .stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "segmentSelection", in: pickerNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

/// Convenience extension for String-labelled pickers
extension GlassSegmentedPicker where Label == Text {
    init<S: StringProtocol>(
        selection: Binding<SelectionValue>,
        label: @escaping (SelectionValue) -> S
    ) {
        self._selection = selection
        self.label = { Text(label($0)) }
    }
}

// MARK: - Menu Picker Style

/// A view modifier that applies styled background to menu pickers
struct GlassMenuPickerStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                PHTVRoundedRect(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.5 : 0.6))
                    .overlay(
                        PHTVRoundedRect(cornerRadius: 8)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 1)
                    )
            }
    }
}

extension View {
    /// Applies Liquid Glass styling to menu pickers
    func glassMenuPickerStyle() -> some View {
        modifier(GlassMenuPickerStyle())
    }
}

// MARK: - Search Field Style

struct GlassSearchFieldStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.5 : 0.6))
                    .overlay(
                        Capsule()
                            .stroke(
                                isFocused ? Color.accentColor.opacity(0.5) : Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1),
                                lineWidth: 1
                            )
                    )
            }
            .focused($isFocused)
    }
}

extension View {
    /// Applies Liquid Glass styling to a search field
    func glassSearchFieldStyle() -> some View {
        modifier(GlassSearchFieldStyle())
    }
}

// MARK: - Conditional Symbol Effects (macOS 14+)

extension View {
    /// Applies pulse symbol effect when available (macOS 14+)
    @ViewBuilder
    func conditionalPulseEffect() -> some View {
        if #available(macOS 14.0, *) {
            self.symbolEffect(.pulse, options: .repeating)
        } else {
            self
        }
    }

    /// Applies pulse symbol effect with value binding when available (macOS 14+)
    @ViewBuilder
    func conditionalPulseEffect<V: Equatable>(value: V) -> some View {
        if #available(macOS 14.0, *) {
            self.symbolEffect(.pulse, options: .repeating, value: value)
        } else {
            self
        }
    }

    /// Applies bounce symbol effect when available (macOS 14+)
    @ViewBuilder
    func conditionalBounceEffect<V: Equatable>(value: V) -> some View {
        if #available(macOS 14.0, *) {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }
}
