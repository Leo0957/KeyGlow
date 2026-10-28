import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var model: AdvancedKeyGlowModel
    var navigate: (MainSection) -> Void

    @State private var showsResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Général", subtitle: "Démarrage, barre des menus, comportement et réglages par défaut.")

            if let error = model.error {
                KeyGlowBanner(title: "Une action n’a pas abouti", message: error)
            }

            startupCard
            menuBarCard
            behaviorCard
            appearanceCard
            resetCard
        }
    }

    private var startupCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(text: "DÉMARRAGE", systemImage: "power")

                SettingRow(
                    "Ouvrir à la connexion",
                    subtitle: "Mécanisme natif macOS. Une version signée placée dans /Applications est nécessaire ; macOS affiche l’erreur si l’enregistrement échoue.",
                    systemImage: "arrow.clockwise.circle"
                ) {
                    Toggle("", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                InlineNote(
                    text: "Au démarrage à la connexion, KeyGlow reste dans la barre des menus : la fenêtre principale ne s’ouvre pas automatiquement.",
                    systemImage: "menubar.rectangle"
                )
            }
        }
    }

    private var menuBarCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(text: "BARRE DES MENUS", systemImage: "menubar.rectangle")

                SettingRow(
                    "Titre à côté de l’icône",
                    subtitle: "Aucun titre, pourcentage, ou nom du preset actif (avec repli sur le pourcentage si le niveau est personnalisé). Le dessin de l’icône ne change pas.",
                    systemImage: "textformat"
                ) {
                    Picker("Titre dans la barre des menus", selection: Binding(get: { model.menuBarTitleMode }, set: { model.setMenuBarTitleMode($0) })) {
                        ForEach(MenuBarTitleMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }

                SettingRow(
                    "Animer l’icône lors d’un réglage",
                    subtitle: "Entrée directionnelle selon le sens du réglage, puis retour adouci vers l’icône neutre. Désactivée si macOS demande de réduire les animations.",
                    systemImage: "waveform.path"
                ) {
                    Toggle("", isOn: Binding(get: { model.menuBarIconAnimations }, set: { model.setMenuBarIconAnimations($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                InlineNote(
                    text: "Le panneau de la barre des menus conserve son apparence actuelle. Cette fenêtre partage ses données et ses services, sans le redessiner.",
                    systemImage: "info.circle"
                )
            }
        }
    }

    private var behaviorCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(text: "COMPORTEMENT", systemImage: "slider.horizontal.3")

                SettingRow(
                    "Restaurer la luminosité au lancement",
                    subtitle: "Si le clavier est éteint au démarrage, KeyGlow rétablit la dernière valeur non nulle.",
                    systemImage: "arrow.uturn.backward"
                ) {
                    Toggle("", isOn: Binding(get: { model.restoreBrightnessOnLaunch }, set: { model.setRestoreBrightnessOnLaunch($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                SettingRow(
                    "Pas des boutons et des raccourcis",
                    subtitle: "Utilisé par +, −, la molette et les raccourcis globaux.",
                    systemImage: "plus.forwardslash.minus"
                ) {
                    Picker("Pas d’ajustement", selection: Binding(get: { model.stepSize }, set: { model.setStepSize($0) })) {
                        Text("1 %").tag(0.01)
                        Text("5 %").tag(0.05)
                        Text("10 %").tag(0.1)
                        Text("20 %").tag(0.2)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                }

                SettingRow(
                    "Afficher le HUD lors des réglages",
                    subtitle: "Le panneau temporaire qui apparaît à l’écran pendant un changement.",
                    systemImage: "rectangle.on.rectangle"
                ) {
                    Toggle("", isOn: Binding(get: { model.showHUD }, set: { model.setShowHUD($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                SettingRow(
                    "Notifier les changements automatiques",
                    subtitle: "Une notification locale lorsqu’un automatisme d’alimentation ou d’horaire applique un niveau. Aucune donnée ne quitte le Mac.",
                    systemImage: "bell"
                ) {
                    Toggle("", isOn: Binding(get: { model.notifyAutomation }, set: { model.setNotifyAutomation($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack {
                    Button("Personnaliser le HUD") { navigate(.hud) }
                        .buttonStyle(.link)
                    Spacer()
                }
            }
        }
    }

    private var appearanceCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(text: "APPARENCE", systemImage: "circle.lefthalf.filled")

                SettingRow(
                    "Apparence de l’application",
                    subtitle: "S’applique à cette fenêtre et au panneau de la barre des menus, sans autre modification.",
                    systemImage: "circle.lefthalf.filled"
                ) {
                    Picker("Apparence", selection: Binding(get: { model.appearance }, set: { model.setAppearance($0) })) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 240)
                }

                InlineNote(text: "« Système » suit le réglage clair ou sombre de macOS.", systemImage: "sun.max")
            }
        }
    }

    private var resetCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(text: "RÉINITIALISATION", systemImage: "arrow.counterclockwise")

                SettingRow(
                    "Rétablir les réglages par défaut",
                    subtitle: "Les presets, leurs favoris et les raccourcis clavier sont conservés.",
                    systemImage: "arrow.counterclockwise",
                    tint: .orange
                ) {
                    Button("Réinitialiser…") { showsResetConfirmation = true }
                        .buttonStyle(.bordered)
                }
            }
            .alert("Rétablir les réglages par défaut ?", isPresented: $showsResetConfirmation) {
                Button("Rétablir", role: .destructive) { model.restoreDefaultSettings() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Les préférences de luminosité, les automatismes et l’apparence du HUD reviennent à leurs valeurs d’origine. Les presets et les raccourcis restent en place.")
            }
        }
    }
}
