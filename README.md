<div align="center">

# ⌨️ KeyGlow

**Le rétroéclairage de votre clavier Mac, à portée de raccourci.**

Une application macOS native pour ajuster la luminosité du clavier, créer des profils et personnaliser les indicateurs visuels, sans quitter ce que vous êtes en train de faire.

![macOS](https://img.shields.io/badge/Plateforme-macOS-222222?style=flat-square&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Langage-Swift-F05138?style=flat-square&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/Interface-SwiftUI-5366D6?style=flat-square)
![Statut](https://img.shields.io/badge/Statut-En%20d%C3%A9veloppement-8A70D6?style=flat-square)

</div>

---

## ✨ Pourquoi KeyGlow ?

Sur les MacBook récents, il n'y a plus de touches dédiées à la luminosité du clavier comme sur certains anciens modèles. KeyGlow vise à rendre ce réglage **rapide, accessible et personnalisable** grâce aux raccourcis clavier et à une application discrète dans la barre des menus.

> **Note :** KeyGlow est un projet en développement. Les fonctionnalités décrites ci-dessous représentent le périmètre du projet ; certaines peuvent encore être en cours d'intégration ou de validation.

## 🚀 Fonctionnalités

### ⌨️ Contrôle rapide du clavier

- Augmenter et diminuer la luminosité du rétroéclairage.
- Ajuster le niveau avec un curseur ou des boutons `+` / `−`.
- Éteindre le rétroéclairage et retrouver un niveau précédent.
- Utiliser des **raccourcis clavier globaux**, même dans une autre application.
- Maintenir un raccourci pour ajuster la luminosité de façon répétée.

### 🧩 Intégration à la barre des menus

- Accéder aux commandes depuis une petite icône dans la **Menu Bar** de macOS.
- Afficher des icônes distinctes pour les états **neutre**, **augmentation** et **diminution**.
- Afficher brièvement une animation lors d'un changement de luminosité.
- Ouvrir les paramètres complets sans encombrer l'écran.

### 🌙 Presets personnalisés

Créer des profils pour retrouver instantanément une luminosité adaptée à chaque situation.

| Preset d'exemple | Luminosité |
|:--|--:|
| 🌙 Nuit | 15 % |
| 💻 Travail | 45 % |
| ☀️ Maximum | 100 % |
| ⏻ Éteint | 0 % |

Les valeurs, noms et raccourcis peuvent être personnalisés selon les fonctionnalités disponibles dans la version installée.

### 🎨 HUD personnalisable

KeyGlow prévoit plusieurs styles pour l'indicateur de luminosité qui apparaît à l'écran :

| Thème | Description |
|:--|:--|
| **Modern Glass** | Un indicateur discret, translucide et contemporain. |
| **Classic iOS** | Un clin d'œil aux anciens indicateurs iOS, avec des segments lumineux. |
| **Minimal** | Une version compacte, centrée sur l'essentiel. |

Les paramètres du HUD comprennent notamment le thème, la position, la durée d'affichage et les animations.

### ⚙️ Application et paramètres

En complément du menu rapide, une **fenêtre macOS dédiée** permet de centraliser :

- Le tableau de bord et le contrôle de la luminosité.
- La création et l'organisation des presets.
- La personnalisation des raccourcis clavier.
- Le choix des thèmes du HUD et leur aperçu.
- Les préférences générales de l'application.

**Les deux interfaces partagent les mêmes réglages** : un changement depuis l'application doit être reflété dans la barre des menus, et inversement.

## 🖼️ Captures d'écran

Des captures du **panneau Menu Bar**, de **l'application principale** et des **trois thèmes du HUD** seront ajoutées au fil du développement.

<!-- Quand les captures seront prêtes, placez-les dans assets/screenshots/ puis ajoutez-les ici.
![Panneau Menu Bar](assets/screenshots/menu-bar.png)
![Fenêtre principale](assets/screenshots/app.png)
![Thèmes HUD](assets/screenshots/hud-themes.png)
-->

## 🛠️ Technologies

- **Swift** — logique de l'application.
- **SwiftUI** — interface macOS native.
- **AppKit** — intégration système lorsque nécessaire (barre des menus, fenêtres et icônes).
- **Xcode** — développement et compilation.
- **Stockage local macOS** — préférences et presets.

## 📦 Installation depuis les sources

> Il n'y a pas encore de procédure de distribution publique confirmée dans ce README.

1. Récupérez les sources du projet sur GitHub.
2. Ouvrez le projet `.xcodeproj` ou l'espace de travail `.xcworkspace` dans **Xcode**, selon la structure du dépôt.
3. Sélectionnez la cible macOS et configurez la signature de développement si Xcode la demande.
4. Compilez et lancez KeyGlow avec **Run** (`⌘R`).
5. Vérifiez que le réglage du rétroéclairage fonctionne sur votre modèle de Mac avant de l'utiliser au quotidien.

La version minimale de macOS et la liste précise des modèles testés seront documentées après validation.

## ⌨️ Exemples de raccourcis

| Action | Combinaison proposée |
|:--|:--|
| Augmenter la luminosité | `⌃ + ⌥ + ↑` |
| Diminuer la luminosité | `⌃ + ⌥ + ↓` |
| Éteindre / restaurer | `⌃ + ⌥ + 0` |
| Ouvrir KeyGlow | `⌃ + ⌥ + K` |

Ces raccourcis sont des **exemples de configuration**, pas une garantie des valeurs par défaut de chaque version. Leur disponibilité dépend aussi des raccourcis déjà utilisés par macOS ou d'autres applications.

## 🗺️ Feuille de route

- [ ] Finaliser et tester la fenêtre principale de l'application.
- [ ] Vérifier la synchronisation entre l'application et la Menu Bar.
- [ ] Finaliser la personnalisation des presets et raccourcis.
- [ ] Valider les thèmes **Modern Glass**, **Classic iOS** et **Minimal**.
- [ ] Tester la compatibilité sur plusieurs versions de macOS et modèles de Mac.
- [ ] Ajouter des captures d'écran et une démonstration.
- [ ] Préparer une première version téléchargeable et documenter son installation.

## ⚠️ Compatibilité et limites

Le contrôle matériel du rétroéclairage dépend du modèle de Mac et des mécanismes disponibles dans macOS. **Apple ne fournit pas d'API publique dédiée au réglage direct de la luminosité du clavier** : selon l'implémentation, certaines fonctions peuvent reposer sur des interfaces système non publiques et devenir incompatibles après une mise à jour.

KeyGlow est conçu pour les **Mac équipés d'un clavier rétroéclairé**. Il ne règle pas la luminosité de l'écran et ne garantit pas la prise en charge de tous les appareils.

## 🔒 Respect de la vie privée

L'objectif de KeyGlow est de fonctionner **localement**, sans compte utilisateur, abonnement ni collecte de données personnelles. Les mécanismes effectivement utilisés seront précisés au fur et à mesure des versions.

## 💬 Retours et suggestions

Une idée de preset, un problème de compatibilité ou une suggestion de design ? Vous pouvez ouvrir une **issue** dans ce dépôt pour en discuter.

---

<div align="center">

**KeyGlow — Un peu plus de contrôle, directement sous vos doigts.** ✨

*Développé pour macOS avec Swift & SwiftUI.*

</div>
