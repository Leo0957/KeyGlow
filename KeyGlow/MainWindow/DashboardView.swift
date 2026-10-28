import SwiftUI

/// Un petit centre de contrôle du rétroéclairage.
struct DashboardView: View {
    @Bindable var model: AdvancedKeyGlowModel
    var navigate: (MainSection) -> Void

    @State private var hudPreview = HUDPresentation()
    @Bindable private var hudSettings = HUDSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Tableau de bord", subtitle: "L’état du clavier et vos réglages les plus utiles, en un coup d’œil.")
            hero

            HStack(alignment: .top, spacing: 16) {
                brightnessCard
                hudCard
            }

            favoritesCard

            if let error = model.error {
                KeyGlowBanner(title: "Le réglage n’a pas pu être appliqué", message: error)
            }

            if model.automaticEnabled {
                InlineNote(
                    text: "L’ajustement automatique de macOS est actif. Un réglage manuel peut le suspendre jusqu’à la fermeture de KeyGlow ; KeyGlow ne modifie jamais cette préférence système.",
                    systemImage: "light.max"
                )
            }
        }
        .onAppear {
            hudPreview.visible = true
            hudPreview.brightness = model.brightness ?? 0.6
            model.refresh()
        }
        .onChange(of: model.brightness) { _, newValue in
            hudPreview.brightness = newValue ?? 0.6
        }
    }

    // MARK: En-tête

    private var hero: some View {
        KeyGlowCard(padding: 22, tint: KeyGlowTheme.accent) {
            HStack(spacing: 18) {
                KeyGlowMark(size: 60)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 9) {
                        Text("KeyGlow")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        statePill
                    }
                    Text("Le rétroéclairage du clavier, réglé au pourcentage près.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Label(activePresetSummary, systemImage: "square.stack.3d.up")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var activePresetSummary: String {
        if let preset = model.activePreset {
            return "Preset actif : \(preset.name) · \(KeyGlowFormat.percentLabel(preset.brightness))"
        }
        return "Niveau personnalisé"
    }

    @ViewBuilder private var statePill: some View {
        if let brightness = model.brightness {
            if brightness < 0.001 {
                KeyGlowPill(text: "Éteint", systemImage: "moon.zzz.fill", tint: .secondary)
            } else {
                KeyGlowPill(text: "Allumé · \(KeyGlowFormat.percent(brightness)) %", systemImage: "keyboard", tint: KeyGlowTheme.accent)
            }
        } else {
            KeyGlowPill(text: "Indisponible", systemImage: "exclamationmark.triangle.fill", tint: .orange)
        }
    }

    // MARK: Luminosité

    private var brightnessCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(text: "LUMINOSITÉ DU CLAVIER", systemImage: "sun.max")

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(KeyGlowFormat.percent(model.brightness))
                        .font(.system(size: 52, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Slider(value: Binding(get: { model.brightness ?? 0 }, set: { model.setLive($0) }), in: 0...1)
                    .tint(KeyGlowTheme.accent)
                    .accessibilityLabel("Luminosité du clavier")
                    .accessibilityValue(KeyGlowFormat.percentLabel(model.brightness))
                    .disabled(model.brightness == nil)

                HStack(spacing: 8) {
                    Button { model.step(-1) } label: {
                        Image(systemName: "minus").frame(width: 16, height: 16)
                    }
                    .buttonStyle(.bordered)
                    .help("Diminuer de \(KeyGlowFormat.percent(model.stepSize)) %")
                    .accessibilityLabel("Diminuer la luminosité")

                    Button { model.step(1) } label: {
                        Image(systemName: "plus").frame(width: 16, height: 16)
                    }
                    .buttonStyle(.bordered)
                    .help("Augmenter de \(KeyGlowFormat.percent(model.stepSize)) %")
                    .accessibilityLabel("Augmenter la luminosité")

                    Spacer(minLength: 4)

                    Button((model.brightness ?? 0) > 0.001 ? "Éteindre" : "Rallumer") { model.toggle() }
                        .buttonStyle(.bordered)
                }
                .disabled(model.brightness == nil)

                Divider().opacity(0.5)

                HStack(spacing: 6) {
                    ForEach(Array(model.favorites.enumerated()), id: \.offset) { index, value in
                        Button("\(KeyGlowFormat.percent(value)) %") { model.applyFavorite(index) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Appliquer le favori \(index + 1)")
                    }
                    Spacer(minLength: 0)
                }
                .disabled(model.brightness == nil)
            }
        }
    }

    // MARK: HUD

    private var hudCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    CardTitle(text: "APERÇU DU HUD", systemImage: "rectangle.on.rectangle")
                    Spacer()
                    Text(hudSettings.theme.rawValue)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }

                HUDPreviewCanvas(
                    presentation: hudPreview,
                    settings: hudSettings,
                    height: 150,
                    maxScale: 0.95
                )

                HStack(spacing: 8) {
                    Button("Tester à l’écran") { model.previewHUD() }
                        .buttonStyle(.bordered)
                        .disabled(!model.showHUD)
                    Spacer(minLength: 0)
                    Button("Personnaliser") { navigate(.hud) }
                        .buttonStyle(.link)
                }
            }
        }
    }

    // MARK: Favoris

    private var favoritesCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    CardTitle(text: "PRESETS FAVORIS", systemImage: "star.fill")
                    Spacer()
                    Button("Gérer les presets") { navigate(.presets) }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }

                if model.favoritePresets.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "star").foregroundStyle(.tertiary)
                        Text("Aucun favori pour l’instant. Ajoutez une étoile à un preset pour le retrouver ici.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        ForEach(model.favoritePresets) { preset in
                            Button { model.applyPreset(id: preset.id) } label: {
                                HStack(spacing: 9) {
                                    IconTile(systemImage: preset.icon, size: 26)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(preset.name)
                                            .font(.system(size: 11.5, weight: .medium))
                                            .lineLimit(1)
                                        Text(KeyGlowFormat.percentLabel(preset.brightness))
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(9)
                                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .help("Activer \(preset.name)")
                        }
                    }
                }
            }
        }
    }
}
