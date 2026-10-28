import SwiftUI

/// Contrôle complet du rétroéclairage, branché sur le contrôleur matériel existant.
struct BrightnessView: View {
    @Bindable var model: AdvancedKeyGlowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Luminosité", subtitle: "Le curseur agit sur le rétroéclairage physique du clavier, jamais sur l’écran.")

            if let error = model.error {
                KeyGlowBanner(title: "Le réglage n’a pas pu être appliqué", message: error)
            }

            controlCard
            actionsCard
            automaticCard
            automationsCard
        }
        .onAppear { model.refresh() }
    }

    // MARK: Réglage

    private var controlCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    CardTitle(text: "NIVEAU ACTUEL", systemImage: "sun.max")
                    Spacer()
                    if let preset = model.activePreset {
                        Label(preset.name, systemImage: preset.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(KeyGlowTheme.accent)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(KeyGlowFormat.percent(model.brightness))
                        .font(.system(size: 64, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(stateLabel)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Slider(value: Binding(get: { model.brightness ?? 0 }, set: { model.setLive($0) }), in: 0...1)
                    .tint(KeyGlowTheme.accent)
                    .accessibilityLabel("Luminosité du clavier")
                    .accessibilityValue(KeyGlowFormat.percentLabel(model.brightness))
                    .disabled(model.brightness == nil)

                HStack(spacing: 10) {
                    Button { model.step(-1) } label: {
                        Label("Baisser", systemImage: "minus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(model.brightness == nil)

                    Button { model.step(1) } label: {
                        Label("Monter", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(model.brightness == nil)

                    Spacer(minLength: 8)

                    Text("Pas")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Picker("Pas d’ajustement", selection: Binding(get: { model.stepSize }, set: { model.setStepSize($0) })) {
                        Text("1 %").tag(0.01)
                        Text("5 %").tag(0.05)
                        Text("10 %").tag(0.1)
                        Text("20 %").tag(0.2)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 230)
                }

                InlineNote(text: "Chaque réglage est écrit puis relu sur le matériel. Si macOS refuse l’écriture, le niveau réel est réaffiché et le pourcentage simulé n’est jamais conservé.", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }

    private var stateLabel: String {
        guard let brightness = model.brightness else { return "Rétroéclairage indisponible" }
        if brightness < 0.001 { return "Clavier éteint" }
        if brightness > 0.999 { return "Niveau maximal" }
        return model.activePreset.map { "Preset « \($0.name) »" } ?? "Niveau personnalisé"
    }

    // MARK: Actions

    private var actionsCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 14) {
                CardTitle(text: "ACTIONS", systemImage: "bolt.fill")

                HStack(spacing: 10) {
                    Button("Éteindre le clavier") { model.turnOff() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled((model.brightness ?? 0) <= 0.001)

                    Button("Rétablir \(KeyGlowFormat.percentLabel(model.previousBrightness))") { model.restorePrevious() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(model.previousBrightness <= 0.001)

                    Spacer(minLength: 0)
                }

                Divider().opacity(0.5)

                if let date = model.temporaryOffUntil {
                    HStack(spacing: 10) {
                        Label("Clavier éteint jusqu’à \(date.formatted(date: .omitted, time: .shortened))", systemImage: "timer")
                            .font(.system(size: 11.5))
                        Spacer()
                        Button("Rétablir maintenant") { model.cancelTemporaryOff() }
                            .buttonStyle(.bordered)
                    }
                } else {
                    HStack(spacing: 10) {
                        Text("Éteindre temporairement")
                            .font(.system(size: 12))
                        Spacer()
                        Menu("Choisir une durée") {
                            Button("15 minutes") { model.turnOffTemporarily(minutes: 15) }
                            Button("30 minutes") { model.turnOffTemporarily(minutes: 30) }
                            Button("1 heure") { model.turnOffTemporarily(minutes: 60) }
                        }
                        .frame(width: 170)
                        .disabled((model.brightness ?? 0) <= 0.001)
                    }
                }

                InlineNote(text: "La luminosité précédente est mémorisée à chaque réglage non nul, y compris entre deux lancements.", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    // MARK: Ajustement automatique

    private var automaticCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(text: "LUMINOSITÉ AUTOMATIQUE", systemImage: "light.max")

                SettingRow(
                    "Ajustement automatique de macOS",
                    subtitle: "Réglé dans Réglages Système › Clavier. KeyGlow lit cet état mais ne le modifie jamais.",
                    systemImage: "sparkles"
                ) {
                    KeyGlowPill(
                        text: model.automaticEnabled ? "Activé" : "Désactivé",
                        tint: model.automaticEnabled ? KeyGlowTheme.accent : .secondary
                    )
                }

                InlineNote(
                    text: "macOS ne fournit pas d’API publique fiable pour réactiver cet automatisme. Après un réglage manuel, les touches de luminosité du clavier restent la solution si l’ajustement est suspendu.",
                    systemImage: "exclamationmark.circle"
                )
            }
        }
    }

    // MARK: Automatismes

    private var automationsCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 14) {
                CardTitle(text: "AUTOMATISMES", systemImage: "clock.arrow.circlepath")

                SettingRow(
                    "Adapter à l’alimentation",
                    subtitle: model.isUsingBattery ? "Source actuelle : batterie." : "Source actuelle : secteur.",
                    systemImage: "bolt.fill",
                    tint: .orange
                ) {
                    Toggle("", isOn: Binding(get: { model.powerAutomationEnabled }, set: { model.setPowerAutomation($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                levelRow("Sur batterie", value: model.batteryBrightness, enabled: model.powerAutomationEnabled) {
                    model.setBatteryBrightness($0)
                }
                levelRow("Sur secteur", value: model.adapterBrightness, enabled: model.powerAutomationEnabled) {
                    model.setAdapterBrightness($0)
                }

                Divider().opacity(0.5)

                SettingRow(
                    "Preset selon l’heure",
                    subtitle: "Le preset s’applique au début de la plage. Un réglage manuel effectué ensuite est conservé.",
                    systemImage: "clock"
                ) {
                    Toggle("", isOn: Binding(get: { model.scheduleEnabled }, set: { model.setScheduleEnabled($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack(spacing: 12) {
                    Picker("De", selection: Binding(get: { model.scheduleStartHour }, set: { model.setScheduleStartHour($0) })) {
                        ForEach(0..<24, id: \.self) { Text("\($0) h").tag($0) }
                    }
                    Picker("à", selection: Binding(get: { model.scheduleEndHour }, set: { model.setScheduleEndHour($0) })) {
                        ForEach(0..<24, id: \.self) { Text("\($0) h").tag($0) }
                    }
                    Picker("Preset", selection: Binding(get: { model.scheduledProfileIndex }, set: { model.setScheduledProfileIndex($0) })) {
                        ForEach(Array(model.profiles.enumerated()), id: \.element.id) { index, preset in
                            Text(preset.name).tag(index)
                        }
                    }
                }
                .disabled(!model.scheduleEnabled)
            }
        }
    }

    private func levelRow(_ title: String, value: Double, enabled: Bool, onChange: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12))
                .frame(width: 96, alignment: .leading)
            Slider(value: Binding(get: { value }, set: onChange), in: 0...1)
                .accessibilityLabel(title)
                .accessibilityValue(KeyGlowFormat.percentLabel(value))
            Text(KeyGlowFormat.percentLabel(value))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.leading, 39)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
    }
}
