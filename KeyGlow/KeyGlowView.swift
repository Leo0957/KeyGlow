import KeyboardShortcuts
import SwiftUI

struct KeyGlowView: View {
    @Bindable var model: KeyGlowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("KeyGlow", systemImage: "keyboard.backlight")
                    .font(.headline)
                Spacer()
                Text(model.brightness.map { "\(Int(($0 * 100).rounded())) %" } ?? "—")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button { model.step(-0.05) } label: { Image(systemName: "minus") }
                    .accessibilityLabel("Diminuer la luminosité du clavier")
                Slider(value: Binding(get: { model.brightness ?? 0 }, set: { model.set($0) }), in: 0...1)
                    .accessibilityLabel("Luminosité du clavier")
                    .disabled(model.brightness == nil)
                Button { model.step(0.05) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Augmenter la luminosité du clavier")
            }
            .disabled(model.brightness == nil)

            Button(model.brightness ?? 0 > 0.001 ? "Éteindre le clavier" : "Rétablir la luminosité") {
                model.toggle()
            }
            .frame(maxWidth: .infinity)
            .disabled(model.brightness == nil)

            if model.automaticEnabled {
                Text("Un réglage manuel suspend l’ajustement automatique jusqu’à la fermeture de KeyGlow ou une action sur les touches système.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            Toggle("Ouvrir à la connexion", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            DisclosureGroup("Raccourcis clavier", isExpanded: $model.showsShortcuts) {
                VStack(alignment: .leading, spacing: 9) {
                    KeyboardShortcuts.Recorder("Augmenter", name: .increase)
                    KeyboardShortcuts.Recorder("Diminuer", name: .decrease)
                    KeyboardShortcuts.Recorder("Éteindre / rétablir", name: .toggle)
                    KeyboardShortcuts.Recorder("Ouvrir le menu", name: .openMenu)
                }
                .padding(.top, 6)
            }

            if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Actualiser") { model.refresh() }
                Spacer()
                Button("Quitter") { model.quit() }
            }
        }
        .padding(18)
        .frame(width: 330)
        .onAppear { model.refresh() }
    }
}
