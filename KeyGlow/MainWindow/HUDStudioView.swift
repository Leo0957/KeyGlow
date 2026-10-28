import Foundation
import SwiftUI

/// Galerie et réglages du HUD existant, avec des aperçus réels et un simulateur sans effet matériel.
struct HUDStudioView: View {
    @Bindable var model: AdvancedKeyGlowModel
    @Bindable private var settings = HUDSettings.shared

    @State private var preview = HUDPresentation()
    @State private var previewBrightness: Double = 0.65

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(
                title: "Apparence du HUD",
                subtitle: "Le HUD apparaît lors d’un réglage de luminosité. Ces options le personnalisent sans modifier le panneau de la barre des menus."
            )

            gallery
            previewCard
            optionsCard
        }
        .onAppear {
            preview.visible = true
            preview.brightness = previewBrightness
        }
        .onChange(of: previewBrightness) { _, newValue in
            preview.brightness = newValue
        }
        .onChange(of: settings.theme) { _, _ in model.previewHUD() }
        .onChange(of: settings.position) { _, _ in model.previewHUD() }
        .onChange(of: settings.size) { _, _ in model.previewHUD() }
        .onChange(of: settings.showsPercentage) { _, _ in model.previewHUD() }
    }

    // MARK: Galerie

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle(text: "THÈMES", systemImage: "square.stack.3d.up")

            ForEach(HUDTheme.allCases) { theme in
                themeCard(theme)
            }
        }
    }

    private func themeCard(_ theme: HUDTheme) -> some View {
        let isSelected = settings.theme == theme

        return Button { settings.theme = theme } label: {
            HStack(alignment: .center, spacing: 18) {
                HUDPreviewCanvas(presentation: preview, settings: settings, theme: theme, height: 188, maxScale: 0.82)
                    .frame(width: 268)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(theme.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                        if isSelected {
                            KeyGlowPill(text: "Appliqué", systemImage: "checkmark")
                        }
                    }
                    Text(description(for: theme))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(isSelected ? "Le HUD actuel utilise ce thème." : "Cliquer pour appliquer ce thème au HUD.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .modifier(KeyGlowSurfaceModifier(tint: isSelected ? KeyGlowTheme.accent : nil))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: KeyGlowTheme.cardRadius, style: .continuous)
                        .strokeBorder(KeyGlowTheme.accent.opacity(0.45), lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: KeyGlowTheme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.rawValue)\(isSelected ? ", thème appliqué" : "")")
    }

    private func description(for theme: HUDTheme) -> String {
        switch theme {
        case .modern:
            "Panneau vitré contemporain, chiffres arrondis et barre de segments lumineux. Le style macOS actuel."
        case .classic:
            "Hommage au HUD de volume d’iOS 6 : pavé bleu-gris translucide, grand pictogramme de clavier et barre segmentée."
        case .minimal:
            "Panneau discret : pictogramme, pourcentage et barre fine, pour rester au second plan."
        case .menuBar:
            "Comme le HUD de volume de macOS : pilule sombre, pictogramme de clavier et segments horizontaux, ancrée sous l’icône KeyGlow de la barre des menus."
        }
    }

    // MARK: Aperçu interactif

    private var previewCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    CardTitle(text: "APERÇU INTERACTIF", systemImage: "eye")
                    Spacer()
                    KeyGlowPill(text: "Sans effet sur le clavier", systemImage: "hand.raised", tint: .secondary)
                }

                HUDPreviewCanvas(presentation: preview, settings: settings, height: 250, maxScale: 1.1)

                HStack(spacing: 10) {
                    Image(systemName: "sun.min")
                        .foregroundStyle(.secondary)
                    Slider(value: $previewBrightness, in: 0...1)
                        .tint(KeyGlowTheme.accent)
                        .accessibilityLabel("Simulation de la luminosité")
                        .accessibilityValue(KeyGlowFormat.percentLabel(previewBrightness))
                    Text(KeyGlowFormat.percentLabel(previewBrightness))
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .frame(width: 46, alignment: .trailing)
                    Image(systemName: "sun.max")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button("Afficher le HUD réel") { model.previewHUD() }
                        .buttonStyle(.bordered)
                        .disabled(!model.showHUD)
                    Text("Le curseur ne fait que simuler : aucun réglage n’est envoyé au matériel.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: Options

    private var optionsCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 14) {
                CardTitle(text: "RÉGLAGES DU HUD", systemImage: "slider.horizontal.3")

                SettingRow(
                    "Thème",
                    subtitle: "Appliqué au HUD existant ; le panneau de la barre des menus reste identique.",
                    systemImage: "sparkles"
                ) {
                    Picker("Thème du HUD", selection: $settings.theme) {
                        ForEach(HUDTheme.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }

                SettingRow(
                    "Position",
                    subtitle: settings.theme == .menuBar
                        ? "Le thème Menu Bar reste ancré sous l’icône de la barre des menus."
                        : "Écran contenant le pointeur.",
                    systemImage: "rectangle.inset.filled"
                ) {
                    Picker("Position du HUD", selection: $settings.position) {
                        ForEach(HUDPosition.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                    .disabled(settings.theme == .menuBar)
                }
                .opacity(settings.theme == .menuBar ? 0.6 : 1)

                SettingRow("Taille", systemImage: "arrow.up.left.and.arrow.down.right") {
                    Picker("Taille du HUD", selection: $settings.size) {
                        ForEach(HUDSize.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                }

                SettingRow(
                    "Durée d’affichage",
                    subtitle: String(format: "%.1f seconde", settings.duration),
                    systemImage: "timer"
                ) {
                    Slider(value: $settings.duration, in: 0.5...3, step: 0.1)
                        .frame(width: 220)
                        .accessibilityLabel("Durée d’affichage du HUD")
                }

                Divider().opacity(0.5)

                SettingRow("Afficher le HUD lors des réglages", systemImage: "rectangle.on.rectangle") {
                    Toggle("", isOn: Binding(get: { model.showHUD }, set: { model.setShowHUD($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                SettingRow(
                    "Animations",
                    subtitle: "Respecte aussi la préférence macOS « Réduire les animations ».",
                    systemImage: "wand.and.stars"
                ) {
                    Toggle("", isOn: $settings.animations)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                SettingRow("Afficher le pourcentage", systemImage: "percent") {
                    Toggle("", isOn: $settings.showsPercentage)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                SettingRow(
                    "Segments jaune et rouge",
                    subtitle: "Colore les derniers segments du thème Classic iOS.",
                    systemImage: "paintpalette"
                ) {
                    Toggle("", isOn: $settings.coloredSegments)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .disabled(settings.theme != .classic)
                .opacity(settings.theme == .classic ? 1 : 0.55)
            }
        }
    }
}

// MARK: - Aperçu

/// Renders the real HUD at a reduced scale over a desktop-like backdrop.
struct HUDPreviewCanvas: View {
    let presentation: HUDPresentation
    var settings: HUDSettings = .shared
    var theme: HUDTheme?
    var height: CGFloat = 160
    var maxScale: CGFloat = 1

    private var resolvedTheme: HUDTheme { theme ?? settings.theme }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                backdrop
                ThemedHUDView(presentation: presentation, settings: settings, themeOverride: theme)
                    .fixedSize()
                    .scaleEffect(fitScale(in: proxy.size))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 0.8)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aperçu du HUD \(resolvedTheme.rawValue)")
    }

    private func fitScale(in size: CGSize) -> CGFloat {
        let natural: CGSize
        switch resolvedTheme {
        case .modern: natural = CGSize(width: 300, height: 124)
        case .classic: natural = CGSize(width: 296, height: 296)
        case .minimal: natural = CGSize(width: 244, height: 90)
        case .menuBar: natural = CGSize(width: 310, height: 76)
        }
        let fit = min(
            (size.width - 26) / natural.width,
            (size.height - 18) / natural.height
        )
        return min(maxScale, max(0.12, fit * settings.size.scale))
    }

    private var backdrop: some View {
        LinearGradient(
            colors: [Color(red: 0.12, green: 0.11, blue: 0.21), Color(red: 0.25, green: 0.18, blue: 0.37)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(KeyGlowTheme.accentBright.opacity(0.35))
                .frame(width: 160, height: 160)
                .blur(radius: 46)
                .offset(x: 46, y: -56)
        }
    }
}
