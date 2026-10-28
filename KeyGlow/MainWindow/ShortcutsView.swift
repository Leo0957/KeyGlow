import AppKit
import KeyboardShortcuts
import SwiftUI

/// Raccourcis globaux existants, présentés comme des touches Apple et modifiables sur place.
struct ShortcutsView: View {
    @Bindable var model: AdvancedKeyGlowModel

    @State private var revision = 0
    @State private var editingID: String?

    private struct Item: Identifiable {
        let id: String
        let name: KeyboardShortcuts.Name
        let title: String
        let subtitle: String
        let symbol: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Raccourcis clavier", subtitle: "Des combinaisons globales, actives même lorsque KeyGlow est en arrière-plan.")

            if !conflicts.isEmpty {
                KeyGlowBanner(
                    title: "Combinaisons attribuées deux fois",
                    message: conflicts
                        .map { "\($0.shortcut.description) — \($0.titles.joined(separator: " · "))" }
                        .joined(separator: "\n"),
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )
            }

            ForEach(groups, id: \.title) { group in
                KeyGlowCard {
                    VStack(alignment: .leading, spacing: 10) {
                        CardTitle(text: group.title.uppercased(), systemImage: "command")
                        VStack(spacing: 2) {
                            ForEach(group.items) { item in
                                shortcutRow(item)
                            }
                        }
                    }
                }
            }

            InlineNote(
                text: "Maintenir « Augmenter » ou « Diminuer » ajuste la luminosité en continu. La bibliothèque vérifie les conflits connus avec macOS ; les doublons internes sont signalés ci-dessus.",
                systemImage: "repeat"
            )
        }
        .onAppear { revision += 1 }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            revision += 1
        }
    }

    // MARK: Données

    @MainActor private var items: [Item] {
        var result: [Item] = [
            Item(id: "increase", name: .increase, title: "Augmenter la luminosité", subtitle: "Maintenir la combinaison ajuste en continu.", symbol: "plus"),
            Item(id: "decrease", name: .decrease, title: "Diminuer la luminosité", subtitle: "Maintenir la combinaison ajuste en continu.", symbol: "minus"),
            Item(id: "toggle", name: .toggle, title: "Éteindre ou rétablir le clavier", subtitle: "Bascule entre zéro et la dernière luminosité non nulle.", symbol: "power"),
            Item(id: "openMenu", name: .openMenu, title: "Ouvrir le panneau de la barre des menus", subtitle: "Affiche le panneau existant, sans le modifier.", symbol: "menubar.rectangle"),
            Item(id: "openMainWindow", name: .openMainWindow, title: "Ouvrir la fenêtre KeyGlow", subtitle: "Amène cette fenêtre au premier plan.", symbol: "macwindow")
        ]

        for index in 0..<min(3, model.profiles.count) {
            guard let name = model.shortcutName(forPresetAt: index) else { continue }
            let preset = model.profiles[index]
            result.append(Item(
                id: "preset\(index)",
                name: name,
                title: "Activer « \(preset.name) »",
                subtitle: "Preset \(index + 1) · \(KeyGlowFormat.percentLabel(preset.brightness))",
                symbol: preset.icon
            ))
        }
        return result
    }

    @MainActor private var groups: [(title: String, items: [Item])] {
        let all = items
        return [
            ("Commandes", Array(all.prefix(5))),
            ("Presets", Array(all.dropFirst(5)))
        ]
    }

    @MainActor private var conflicts: [(shortcut: KeyboardShortcuts.Shortcut, titles: [String])] {
        _ = revision
        var map: [KeyboardShortcuts.Shortcut: [String]] = [:]
        for item in items {
            if let shortcut = KeyboardShortcuts.getShortcut(for: item.name) {
                map[shortcut, default: []].append(item.title)
            }
        }
        return map
            .filter { $0.value.count > 1 }
            .map { (shortcut: $0.key, titles: $0.value) }
            .sorted { $0.shortcut.description < $1.shortcut.description }
    }

    @MainActor private func shortcut(for item: Item) -> KeyboardShortcuts.Shortcut? {
        _ = revision
        return KeyboardShortcuts.getShortcut(for: item.name)
    }

    // MARK: Ligne

    private func shortcutRow(_ item: Item) -> some View {
        let shortcut = shortcut(for: item)

        return HStack(spacing: 12) {
            IconTile(systemImage: item.symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: .medium))
                Text(item.subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)

            ShortcutKeycaps(shortcut: shortcut)
                .frame(minWidth: 112, alignment: .trailing)

            Button { editingID = item.id } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .help("Modifier le raccourci")
            .accessibilityLabel("Modifier le raccourci de \(item.title)")
            .popover(isPresented: Binding(get: { editingID == item.id }, set: { if !$0 { editingID = nil } })) {
                popoverContent(for: item)
            }

            Button {
                KeyboardShortcuts.setShortcut(nil, for: item.name)
                revision += 1
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .disabled(shortcut == nil)
            .help("Effacer le raccourci")
            .accessibilityLabel("Effacer le raccourci de \(item.title)")
        }
        .padding(.vertical, 5)
    }

    private func popoverContent(for item: Item) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(.system(size: 12, weight: .semibold))
            KeyboardShortcuts.Recorder(for: item.name) { _ in revision += 1 }
            Text("Cliquez sur le champ puis appuyez sur la combinaison souhaitée. Échap annule l’enregistrement.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Terminé") { editingID = nil }
            }
        }
        .padding(14)
        .frame(width: 290)
    }
}
