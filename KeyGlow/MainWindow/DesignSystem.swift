import AppKit
import KeyboardShortcuts
import SwiftUI

// MARK: - Thème

enum KeyGlowTheme {
    static let accent = Color(red: 0.40, green: 0.34, blue: 0.94)
    static let accentBright = Color(red: 0.62, green: 0.38, blue: 0.97)
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.44, green: 0.34, blue: 0.97), Color(red: 0.67, green: 0.37, blue: 0.95)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cardRadius: CGFloat = 20

    /// Soft violet wash that gives translucent surfaces something to refract.
    static var canvas: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [accent.opacity(0.10), .clear, accentBright.opacity(0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(colors: [accent.opacity(0.07), .clear], center: .topTrailing, startRadius: 40, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

enum KeyGlowFormat {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((min(1, max(0, value)) * 100).rounded()))"
    }

    static func percentLabel(_ value: Double?) -> String { "\(percent(value)) %" }
}

// MARK: - Surfaces

struct KeyGlowSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = KeyGlowTheme.cardRadius
    var tint: Color?

    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            if let tint {
                content.glassEffect(.regular.tint(tint.opacity(0.18)), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
    }
}

struct KeyGlowCard<Content: View>: View {
    private let padding: CGFloat
    private let tint: Color?
    private let content: Content

    init(padding: CGFloat = 20, tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .modifier(KeyGlowSurfaceModifier(tint: tint))
    }
}

// MARK: - Logo

struct KeyGlowMark: View {
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(KeyGlowTheme.accentGradient)
            .overlay {
                Image("KeyGlowIconLarge")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .padding(size * 0.23)
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 0.8)
            }
            .shadow(color: KeyGlowTheme.accent.opacity(0.32), radius: size * 0.18, y: size * 0.08)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Typographie et en-têtes

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 25, weight: .bold))
            Text(subtitle)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CardTitle: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10.5, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(0.3)
        }
        .foregroundStyle(.secondary)
        .accessibilityAddTraits(.isHeader)
    }
}

struct IconTile: View {
    let systemImage: String
    var tint: Color = KeyGlowTheme.accent
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
    }
}

struct KeyGlowPill: View {
    let text: String
    var systemImage: String?
    var tint: Color = KeyGlowTheme.accent

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 9.5, weight: .bold))
            }
            Text(text).font(.system(size: 10.5, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 0.7))
    }
}

struct InlineNote: View {
    let text: String
    var systemImage: String = "info.circle"

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
}

struct KeyGlowBanner: View {
    let title: String
    let message: String
    var systemImage: String = "exclamationmark.triangle.fill"
    var tint: Color = .orange

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 0.8)
        }
    }
}

// MARK: - Lignes de réglage

struct SettingRow<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let systemImage: String?
    private let tint: Color
    private let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        tint: Color = KeyGlowTheme.accent,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            if let systemImage {
                IconTile(systemImage: systemImage, tint: tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
    }
}

extension SettingRow where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil, systemImage: String? = nil, tint: Color = KeyGlowTheme.accent) {
        self.init(title, subtitle: subtitle, systemImage: systemImage, tint: tint) { EmptyView() }
    }
}

// MARK: - Touches de clavier

struct KeyCap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(minWidth: 23, minHeight: 22)
            .padding(.horizontal, 5)
            .background {
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(nsColor: .controlBackgroundColor), Color(nsColor: .windowBackgroundColor)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .strokeBorder(.primary.opacity(0.16), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.16), radius: 0.4, y: 1)
    }
}

struct ShortcutKeycaps: View {
    let shortcut: KeyboardShortcuts.Shortcut?

    var body: some View {
        if let shortcut {
            HStack(spacing: 3) {
                ForEach(modifierSymbols(shortcut.modifiers), id: \.self) { symbol in
                    KeyCap(label: symbol)
                }
                KeyCap(label: keyLabel(shortcut))
            }
        } else {
            Text("Non défini")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    @MainActor
    private func modifierSymbols(_ flags: NSEvent.ModifierFlags) -> [String] {
        var symbols: [String] = []
        if flags.contains(.control) { symbols.append("⌃") }
        if flags.contains(.option) { symbols.append("⌥") }
        if flags.contains(.shift) { symbols.append("⇧") }
        if flags.contains(.command) { symbols.append("⌘") }
        return symbols
    }

    @MainActor
    private func keyLabel(_ shortcut: KeyboardShortcuts.Shortcut) -> String {
        guard let key = shortcut.nsMenuItemKeyEquivalent, !key.isEmpty else { return "?" }
        return key == " " ? "Espace" : key.uppercased()
    }
}

