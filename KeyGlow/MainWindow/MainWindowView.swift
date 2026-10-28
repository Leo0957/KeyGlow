import SwiftUI

enum MainSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard, brightness, presets, shortcuts, hud, general, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Tableau de bord"
        case .brightness: "Luminosité"
        case .presets: "Presets"
        case .shortcuts: "Raccourcis clavier"
        case .hud: "Apparence du HUD"
        case .general: "Général"
        case .about: "À propos"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .brightness: "sun.max"
        case .presets: "square.stack.3d.up"
        case .shortcuts: "command"
        case .hud: "rectangle.on.rectangle"
        case .general: "gearshape"
        case .about: "info.circle"
        }
    }
}

/// The main window. It reads and writes the same model as the menu bar panel.
struct MainWindowView: View {
    @Bindable var model: AdvancedKeyGlowModel

    @State private var selection: MainSection? = .dashboard

    private var activeSection: MainSection { selection ?? .dashboard }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 214, ideal: 232, max: 300)
        } detail: {
            detail
        }
        .tint(KeyGlowTheme.accent)
        .frame(minWidth: 900, minHeight: 620)
        .onAppear { model.refresh() }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            brand

            List(selection: $selection) {
                Section("Contrôles") {
                    ForEach([MainSection.dashboard, .brightness, .presets]) { section in
                        row(section)
                    }
                }
                Section("Personnalisation") {
                    ForEach([MainSection.shortcuts, .hud]) { section in
                        row(section)
                    }
                }
                Section("Application") {
                    ForEach([MainSection.general, .about]) { section in
                        row(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }

    private func row(_ section: MainSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
            .tag(section)
            .padding(.vertical, 1)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            KeyGlowMark(size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("KeyGlow")
                    .font(.system(size: 13, weight: .semibold))
                Text("Rétroéclairage du clavier")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var detail: some View {
        ZStack {
            KeyGlowTheme.canvas
            ScrollView {
                page
                    .frame(maxWidth: 820, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.top, 22)
                    .padding(.bottom, 36)
            }
        }
    }

    @ViewBuilder private var page: some View {
        switch activeSection {
        case .dashboard:
            DashboardView(model: model) { selection = $0 }
        case .brightness:
            BrightnessView(model: model)
        case .presets:
            PresetsView(model: model)
        case .shortcuts:
            ShortcutsView(model: model)
        case .hud:
            HUDStudioView(model: model)
        case .general:
            GeneralSettingsView(model: model) { selection = $0 }
        case .about:
            AboutView()
        }
    }
}
