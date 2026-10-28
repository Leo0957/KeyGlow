import AppKit
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            descriptionCard
            compatibilityCard
            creditsCard
        }
    }

    // MARK: En-tête

    private var header: some View {
        KeyGlowCard(padding: 26, tint: KeyGlowTheme.accent) {
            VStack(spacing: 12) {
                KeyGlowMark(size: 84)

                VStack(spacing: 3) {
                    Text("KeyGlow")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(versionText)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Text("Le rétroéclairage du clavier, réglé avec précision depuis la barre des menus ou cette fenêtre.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 440)

                HStack(spacing: 8) {
                    KeyGlowPill(text: "Barre des menus", systemImage: "menubar.rectangle", tint: .secondary)
                    KeyGlowPill(text: "100 % local", systemImage: "lock.shield", tint: .secondary)
                    KeyGlowPill(text: "Sans télémétrie", systemImage: "network.slash", tint: .secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var versionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (short, build) {
        case let (short?, build?):
            return "Version \(short) (\(build))"
        case let (short?, nil):
            return "Version \(short)"
        default:
            return "Version non renseignée"
        }
    }

    // MARK: Description

    private var descriptionCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(text: "L’APPLICATION", systemImage: "keyboard")

                Text("KeyGlow règle le rétroéclairage physique du clavier des Mac portables. Il propose des favoris, des presets nommés, un HUD temporaire, des automatismes d’alimentation et d’horaire, ainsi que des raccourcis globaux.")
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)

                Text("La luminosité de l’écran n’est jamais touchée. Aucun serveur, aucun compte, aucune donnée ne quitte ce Mac : les préférences et les raccourcis restent dans UserDefaults.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Compatibilité

    private var compatibilityCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(text: "COMPATIBILITÉ", systemImage: "checkmark.seal")

                SettingRow("Système", subtitle: "Version minimale déclarée dans le projet.", systemImage: "apple.logo") {
                    Text(minimumSystem).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }

                SettingRow("Processeur", systemImage: "cpu") {
                    Text(architecture).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }

                SettingRow(
                    "Matériel",
                    subtitle: "Un clavier rétroéclairé intégré est nécessaire ; un clavier externe sans rétroéclairage n’expose aucun niveau réglable.",
                    systemImage: "keyboard"
                )

                SettingRow(
                    "Barre des menus",
                    subtitle: "KeyGlow reste utilisable sans fenêtre ouverte et n’apparaît dans le Dock que lorsque sa fenêtre est affichée.",
                    systemImage: "menubar.rectangle"
                )
            }
        }
    }

    private var minimumSystem: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String else {
            return "Voir Info.plist"
        }
        return "macOS \(version) ou ultérieur"
    }

    private var architecture: String {
        #if arch(arm64)
        "Apple Silicon (arm64)"
        #elseif arch(x86_64)
        "Intel (x86_64)"
        #else
        "Architecture non identifiée"
        #endif
    }

    // MARK: Crédits

    private var creditsCard: some View {
        KeyGlowCard {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(text: "BIBLIOTHÈQUES ET CRÉDITS", systemImage: "shippingbox")

                SettingRow(
                    "KeyboardShortcuts",
                    subtitle: "Raccourcis globaux et détection des conflits connus avec macOS. Version 3.1.0 ou ultérieure.",
                    systemImage: "command"
                ) {
                    Link("GitHub", destination: URL(string: "https://github.com/sindresorhus/KeyboardShortcuts")!)
                        .font(.system(size: 11))
                }

                SettingRow(
                    "MenuBarExtraAccess",
                    subtitle: "Ouverture du panneau de la barre des menus par raccourci. Version 1.3.1 ou ultérieure.",
                    systemImage: "menubar.rectangle"
                ) {
                    Link("GitHub", destination: URL(string: "https://github.com/orchetect/MenuBarExtraAccess")!)
                        .font(.system(size: 11))
                }

                SettingRow(
                    "CoreBrightness",
                    subtitle: "API privée de macOS utilisée uniquement pour lire et écrire le rétroéclairage. Elle peut changer sans préavis ; une telle application n’est pas destinée au Mac App Store.",
                    systemImage: "lock"
                ) {
                    Text("Interne").font(.system(size: 11.5)).foregroundStyle(.secondary)
                }

                Divider().opacity(0.5)

                SettingRow(
                    "Dépôt du projet",
                    subtitle: "Aucun dépôt GitHub n’est configuré pour ce projet.",
                    systemImage: "link"
                )
            }
        }
    }
}
