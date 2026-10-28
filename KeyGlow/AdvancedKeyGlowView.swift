import KeyboardShortcuts
import SwiftUI

struct AdvancedKeyGlowView: View {
    @Bindable var model: AdvancedKeyGlowModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                brightnessControl
                if let automation = model.activeAutomationDescription {
                    Text(automation)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                favorites
                profiles
                temporaryControl

                if model.automaticEnabled {
                    Text("Un réglage manuel peut suspendre l’ajustement automatique de macOS jusqu’à la fermeture de KeyGlow ou une action sur les touches système.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()
                preferences
                HUDSettingsView(model: model)
                automation
                shortcuts

                if let error = model.error {
                    Text(error).font(.caption).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                footer
            }
            .padding(18)
        }
        .frame(width: 380, height: 620)
        .onAppear { model.refresh() }
        .onExitCommand { model.isMenuPresented = false }
        .onChange(of: model.showsProfileEditor) { _, value in
            UserDefaults.standard.set(value, forKey: PanelDisclosureKeys.profileEditor)
        }
        .onChange(of: model.showsShortcuts) { _, value in
            UserDefaults.standard.set(value, forKey: PanelDisclosureKeys.shortcuts)
        }
        .onChange(of: model.showsAutomation) { _, value in
            UserDefaults.standard.set(value, forKey: PanelDisclosureKeys.automation)
        }
    }

    private var header: some View {
        HStack {
            Label("KeyGlow", systemImage: "keyboard.backlight").font(.headline)
            Spacer()
            Text(model.brightness.map { "\(Int(($0 * 100).rounded())) %" } ?? "—")
                .monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private var brightnessControl: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { model.step(-1) } label: { Image(systemName: "minus") }
                    .keyboardShortcut(.downArrow, modifiers: .command)
                    .help("Diminuer (⌘↓)")
                    .accessibilityLabel("Diminuer la luminosité du clavier")
                Slider(value: Binding(get: { model.brightness ?? 0 }, set: { model.setLive($0) }), in: 0...1)
                    .accessibilityLabel("Luminosité du clavier")
                    .disabled(model.brightness == nil)
                Button { model.step(1) } label: { Image(systemName: "plus") }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                    .help("Augmenter (⌘↑)")
                    .accessibilityLabel("Augmenter la luminosité du clavier")
            }
            Button(model.brightness ?? 0 > 0.001 ? "Éteindre le clavier" : "Rétablir la luminosité") { model.toggle() }
                .frame(maxWidth: .infinity)
                .disabled(model.brightness == nil)
                .keyboardShortcut("0", modifiers: .command)
                .help("Éteindre ou rétablir (⌘0)")
        }
        .disabled(model.brightness == nil)
    }

    private var favorites: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Favoris").font(.caption).foregroundStyle(.secondary)
            HStack {
                ForEach([0, 1, 2], id: \.self) { index in
                    Button("\(Int((model.favorites[index] * 100).rounded())) %") { model.applyFavorite(index) }
                        .frame(maxWidth: .infinity)
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                        .help("Appliquer le favori \(index + 1) (⌘\(index + 1))")
                }
            }
            if !model.favoritePresets.isEmpty {
                HStack(spacing: 6) {
                    ForEach(model.favoritePresets.prefix(3)) { preset in
                        Button {
                            model.applyPreset(id: preset.id)
                        } label: {
                            Label(preset.name, systemImage: preset.icon)
                                .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Activer « \(preset.name) » — \(Int((preset.brightness * 100).rounded())) %")
                    }
                }
            }
        }
    }

    private var profiles: some View {
        DisclosureGroup("Profils", isExpanded: $model.showsProfileEditor) {
            VStack(spacing: 10) {
                ForEach(Array(model.profiles.enumerated()), id: \.element.id) { index, profile in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            TextField("Nom", text: Binding(
                                get: { model.profiles[index].name },
                                set: { model.updateProfile(index, name: $0) }
                            ))
                            Button("Appliquer") { model.applyProfile(index) }
                        }
                        HStack {
                            Slider(value: Binding(
                                get: { model.profiles[index].brightness },
                                set: { model.updateProfile(index, brightness: $0) }
                            ), in: 0...1)
                            Text("\(Int((profile.brightness * 100).rounded())) %")
                                .monospacedDigit().frame(width: 42, alignment: .trailing)
                        }
                    }
                }
                Divider()
                Text("Valeurs des trois favoris").font(.caption).foregroundStyle(.secondary)
                ForEach([0, 1, 2], id: \.self) { index in
                    HStack {
                        Text("Favori \(index + 1)")
                        Slider(value: Binding(
                            get: { model.favorites[index] },
                            set: { model.updateFavorite(index, value: $0) }
                        ), in: 0...1)
                        Text("\(Int((model.favorites[index] * 100).rounded())) %")
                            .monospacedDigit().frame(width: 42, alignment: .trailing)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder private var temporaryControl: some View {
        if let date = model.temporaryOffUntil {
            HStack {
                TimelineView(.periodic(from: .now, by: 20)) { context in
                    Label(remainingText(until: date, now: context.date), systemImage: "timer")
                        .font(.caption)
                }
                Spacer()
                Button("Rétablir") { model.cancelTemporaryOff() }
            }
        } else {
            Menu("Éteindre temporairement") {
                Button("15 minutes") { model.turnOffTemporarily(minutes: 15) }
                Button("30 minutes") { model.turnOffTemporarily(minutes: 30) }
                Button("1 heure") { model.turnOffTemporarily(minutes: 60) }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var preferences: some View {
        VStack(alignment: .leading, spacing: 9) {
            Toggle("Ouvrir à la connexion", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            Toggle("Afficher le pourcentage dans la barre des menus", isOn: Binding(get: { model.showPercentage }, set: { model.setShowPercentage($0) }))
                .help("Un titre personnalisé (pourcentage ou nom du preset) se règle dans la fenêtre, page Général.")
            HStack {
                Text("Pas des boutons et raccourcis")
                Spacer()
                Picker("Pas", selection: Binding(get: { model.stepSize }, set: { model.setStepSize($0) })) {
                    Text("1 %").tag(0.01)
                    Text("5 %").tag(0.05)
                    Text("10 %").tag(0.1)
                    Text("20 %").tag(0.2)
                }
                .labelsHidden().frame(width: 82)
            }
            Text("Astuce : fais défiler la molette sur l’icône KeyGlow pour régler la luminosité.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var automation: some View {
        DisclosureGroup("Automatismes", isExpanded: $model.showsAutomation) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Adapter à l’alimentation", isOn: Binding(get: { model.powerAutomationEnabled }, set: { model.setPowerAutomation($0) }))
                levelRow("Sur batterie", value: model.batteryBrightness) { model.setBatteryBrightness($0) }
                levelRow("Sur secteur", value: model.adapterBrightness) { model.setAdapterBrightness($0) }
                Text(model.isUsingBattery ? "Source actuelle : batterie" : "Source actuelle : secteur")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Toggle("Appliquer un profil selon l’heure", isOn: Binding(get: { model.scheduleEnabled }, set: { model.setScheduleEnabled($0) }))
                HStack {
                    Picker("De", selection: Binding(get: { model.scheduleStartHour }, set: { model.setScheduleStartHour($0) })) {
                        ForEach(0..<24, id: \.self) { Text("\($0) h").tag($0) }
                    }
                    Picker("à", selection: Binding(get: { model.scheduleEndHour }, set: { model.setScheduleEndHour($0) })) {
                        ForEach(0..<24, id: \.self) { Text("\($0) h").tag($0) }
                    }
                }
                Picker("Profil programmé", selection: Binding(get: { model.scheduledProfileIndex }, set: { model.setScheduledProfileIndex($0) })) {
                    ForEach(Array(model.profiles.enumerated()), id: \.element.id) { index, profile in
                        Text(profile.name).tag(index)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var shortcuts: some View {
        DisclosureGroup(isExpanded: $model.showsShortcuts) {
            VStack(alignment: .leading, spacing: 9) {
                KeyboardShortcuts.Recorder("Augmenter", name: .increase)
                KeyboardShortcuts.Recorder("Diminuer", name: .decrease)
                KeyboardShortcuts.Recorder("Éteindre / rétablir", name: .toggle)
                KeyboardShortcuts.Recorder("Ouvrir le menu", name: .openMenu)
                Divider()
                ForEach(Array(model.profiles.prefix(3).enumerated()), id: \.element.id) { index, profile in
                    KeyboardShortcuts.Recorder(profile.name, name: Self.profileSlotName(index))
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 6) {
                Text("Raccourcis clavier")
                if model.hasShortcutConflicts {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help("Deux actions partagent la même combinaison.")
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Réglages…") { MainWindowController.shared.show() }
            Spacer()
            Button("Actualiser") { model.refresh() }
            Button("Quitter") { model.quit() }
        }
    }

    private func remainingText(until date: Date, now: Date) -> String {
        let end = date.formatted(date: .omitted, time: .shortened)
        let remaining = date.timeIntervalSince(now)
        guard remaining >= 60 else { return "Éteint jusqu’à \(end)" }
        return "Éteint jusqu’à \(end) · \(Int((remaining / 60).rounded(.up))) min"
    }

    private static func profileSlotName(_ index: Int) -> KeyboardShortcuts.Name {
        switch index {
        case 0: .profile1
        case 1: .profile2
        default: .profile3
        }
    }

    private func levelRow(_ title: String, value: Double, onChange: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title)
            Slider(value: Binding(get: { value }, set: onChange), in: 0...1)
            Text("\(Int((value * 100).rounded())) %").monospacedDigit().frame(width: 42, alignment: .trailing)
        }
    }
}
