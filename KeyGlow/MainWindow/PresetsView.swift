import KeyboardShortcuts
import SwiftUI

struct PresetDraft: Identifiable {
    let id: UUID
    var name: String
    var icon: String
    var brightness: Double
    var isFavorite: Bool
    var isNew: Bool

    static func new(defaultBrightness: Double) -> PresetDraft {
        PresetDraft(
            id: UUID(),
            name: "",
            icon: "keyboard",
            brightness: min(1, max(0.01, defaultBrightness)),
            isFavorite: false,
            isNew: true
        )
    }

    init(preset: BrightnessProfile) {
        self.id = preset.id
        self.name = preset.name
        self.icon = preset.icon
        self.brightness = preset.brightness
        self.isFavorite = preset.isFavorite
        self.isNew = false
    }

    init(id: UUID, name: String, icon: String, brightness: Double, isFavorite: Bool, isNew: Bool) {
        self.id = id
        self.name = name
        self.icon = icon
        self.brightness = brightness
        self.isFavorite = isFavorite
        self.isNew = isNew
    }
}

/// Création, édition, favoris et réorganisation des presets partagés avec la barre des menus.
struct PresetsView: View {
    @Bindable var model: AdvancedKeyGlowModel

    @State private var editing: PresetDraft?
    @State private var pendingDeletion: BrightnessProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 16) {
                PageHeader(title: "Presets", subtitle: "Un nom, une icône, un niveau et un favori. Les trois premiers restent disponibles dans la barre des menus.")
                Spacer(minLength: 8)
                Button {
                    editing = .new(defaultBrightness: model.brightness ?? 0.5)
                } label: {
                    Label("Nouveau preset", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 244), spacing: 14)], spacing: 14) {
                ForEach(Array(model.profiles.enumerated()), id: \.element.id) { index, preset in
                    presetCard(preset, index: index)
                }
            }

            InlineNote(
                text: "Glissez une carte pour réorganiser la liste. Les trois premières définissent aussi l’ordre des raccourcis de la barre des menus.",
                systemImage: "arrow.up.arrow.down"
            )

            InlineNote(
                text: "Un preset au moins est toujours conservé, afin que la barre des menus garde un niveau à appliquer.",
                systemImage: "info.circle"
            )
        }
        .sheet(item: $editing) { draft in
            PresetEditorSheet(model: model, draft: draft)
        }
        .confirmationDialog(
            "Supprimer « \(pendingDeletion?.name ?? "") » ?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { preset in
            Button("Supprimer", role: .destructive) {
                model.deletePreset(id: preset.id)
                pendingDeletion = nil
            }
            Button("Annuler", role: .cancel) { pendingDeletion = nil }
        } message: { _ in
            Text("Le preset sera retiré de la liste et du panneau de la barre des menus. Cette action est immédiate.")
        }
    }

    private func presetCard(_ preset: BrightnessProfile, index: Int) -> some View {
        let isActive = model.activePreset?.id == preset.id

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconTile(systemImage: preset.icon, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(index < 3 ? "Barre des menus · emplacement \(index + 1)" : "Hors barre des menus")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button {
                    model.setFavorite(!preset.isFavorite, forPreset: preset.id)
                } label: {
                    Image(systemName: preset.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(preset.isFavorite ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help(preset.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
                .accessibilityLabel(preset.isFavorite ? "Retirer \(preset.name) des favoris" : "Ajouter \(preset.name) aux favoris")
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(KeyGlowFormat.percent(preset.brightness))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if isActive {
                    KeyGlowPill(text: "Actif", systemImage: "checkmark")
                }
            }

            HStack(spacing: 8) {
                Button("Activer") { model.applyPreset(id: preset.id) }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.brightness == nil)

                Button { editing = PresetDraft(preset: preset) } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .help("Modifier ce preset")
                .accessibilityLabel("Modifier \(preset.name)")

                Spacer(minLength: 0)

                Menu {
                    Button("Modifier…") { editing = PresetDraft(preset: preset) }
                    Divider()
                    Button("Monter") { model.movePreset(id: preset.id, offset: -1) }
                        .disabled(index == 0)
                    Button("Descendre") { model.movePreset(id: preset.id, offset: 1) }
                        .disabled(index == model.profiles.count - 1)
                    Divider()
                    Button("Supprimer…", role: .destructive) { pendingDeletion = preset }
                        .disabled(!model.canDeletePresets)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Plus d’options")
            }
        }
        .padding(16)
        .modifier(KeyGlowSurfaceModifier(tint: isActive ? KeyGlowTheme.accent : nil))
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: KeyGlowTheme.cardRadius, style: .continuous)
                    .strokeBorder(KeyGlowTheme.accent.opacity(0.45), lineWidth: 1)
            }
        }
        .draggable(preset.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = UUID(uuidString: raw), id != preset.id else { return false }
            withAnimation(.easeInOut(duration: 0.2)) {
                model.movePreset(id: id, before: preset.id)
            }
            return true
        }
    }
}

// MARK: - Éditeur

private struct PresetEditorSheet: View {
    let model: AdvancedKeyGlowModel
    let presetID: UUID
    let isNew: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var icon: String
    @State private var brightness: Double
    @State private var isFavorite: Bool

    private static let icons = [
        "keyboard", "briefcase", "moon.stars", "film",
        "sun.max", "sparkles", "laptopcomputer", "gamecontroller",
        "headphones", "book", "pencil", "cup.and.saucer",
        "leaf", "bolt.fill", "eye", "music.note"
    ]

    init(model: AdvancedKeyGlowModel, draft: PresetDraft) {
        self.model = model
        self.presetID = draft.id
        self.isNew = draft.isNew
        _name = State(initialValue: draft.name)
        _icon = State(initialValue: draft.icon)
        _brightness = State(initialValue: draft.brightness)
        _isFavorite = State(initialValue: draft.isFavorite)
    }

    private var slotIndex: Int? {
        guard !isNew, let index = model.presetIndex(for: presetID), index < 3 else { return nil }
        return index
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "Nouveau preset" : "Modifier le preset")
                .font(.system(size: 16, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Nom")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Nom du preset", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Icône")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 8), count: 8), spacing: 8) {
                    ForEach(Self.icons, id: \.self) { symbol in
                        Button { icon = symbol } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(icon == symbol ? Color.white : Color.secondary)
                                .frame(width: 30, height: 30)
                                .background {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(icon == symbol ? KeyGlowTheme.accent : Color.primary.opacity(0.06))
                                }
                        }
                        .buttonStyle(.plain)
                        .help(symbol)
                        .accessibilityLabel(symbol)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Luminosité")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(KeyGlowFormat.percentLabel(brightness))
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                }
                Slider(value: $brightness, in: 0...1)
                    .tint(KeyGlowTheme.accent)
                    .accessibilityLabel("Luminosité du preset")
            }

            Toggle("Ajouter aux favoris du tableau de bord", isOn: $isFavorite)
                .toggleStyle(.switch)

            if let index = slotIndex, let shortcutName = model.shortcutName(forPresetAt: index) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Raccourci")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        KeyboardShortcuts.Recorder(for: shortcutName)
                            .frame(width: 150)
                        Text("Lié à l’emplacement \(index + 1) de la barre des menus.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
            } else if isNew {
                InlineNote(
                    text: "Un raccourci pourra être attribué après l’enregistrement, si ce preset figure parmi les trois premiers.",
                    systemImage: "command"
                )
            }

            InlineNote(text: "Le niveau est appliqué au clavier avec le bouton « Activer », jamais à l’enregistrement seul.", systemImage: "hand.tap")

            HStack {
                Spacer()
                Button("Annuler") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Créer" : "Enregistrer") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 430)
    }

    private func save() {
        if isNew {
            let id = model.addPreset(name: name, icon: icon, brightness: brightness)
            model.updatePreset(id: id, isFavorite: isFavorite)
        } else {
            model.updatePreset(id: presetID, name: name, icon: icon, brightness: brightness, isFavorite: isFavorite)
        }
        dismiss()
    }
}
