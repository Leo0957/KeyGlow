# KeyGlow

Application macOS native pour régler le **rétroéclairage physique du clavier** depuis la barre des menus. Le curseur ne touche jamais à la luminosité de l’écran.

## Fonctions

- Fenêtre principale native : tableau de bord, luminosité, presets, raccourcis, HUD, général et à propos.
- Trois favoris de luminosité et des profils (presets) personnalisables, avec icône et favori.
- Presets : création, modification, suppression, réorganisation par glisser-déposer et activation immédiate.
- HUD temporaire lors d’un réglage : style « Menu Bar » proche du HUD de volume de macOS, ancré sous l’icône de KeyGlow.
- Pas de réglage au choix : 1 %, 5 % ou 10 %.
- Niveaux automatiques distincts sur batterie et sur secteur.
- Réglage à la molette directement sur l’icône de la barre des menus.
- Application programmée d’un profil sur une plage horaire.
- Extinction temporaire pendant 15, 30 ou 60 minutes avec restauration automatique.
- Titre facultatif dans la barre des menus : aucun, pourcentage ou nom du preset actif.
- Menu natif au clic droit (ou clic avec Option) sur l’icône : presets, extinction temporaire, HUD, Réglages, Quitter.
- Raccourcis dans le panneau : ⌘1 à ⌘3 pour les favoris, ⌘0 pour éteindre/rétablir, ⌘↑ et ⌘↓ pour le pas, Échap pour fermer.
- Sections du panneau (profils, automatismes, raccourcis) mémorisées entre deux lancements.
- Notification locale facultative lorsqu’un automatisme d’alimentation ou d’horaire applique un niveau.
- Extinction temporaire conservée après un relancement, avec compte à rebours.
- Reprise automatique du contrôleur après une veille, et écritures lissées pendant le glissement du curseur.
- Raccourcis globaux pour les trois profils, en plus des commandes générales.
- Icône dynamique dans la barre des menus : entrée directionnelle (l’icône glisse vers le haut ou vers le bas selon le sens du réglage), micro-pulsation à chaque cran et retour adouci vers l’icône neutre environ 700 ms après le dernier réglage.

Les réglages, favoris et profils sont enregistrés localement dans `UserDefaults`. La surveillance de l’alimentation utilise les notifications système et la programmation vérifie l’heure une fois par minute avec une tolérance pour limiter le travail en arrière-plan.

Les trois icônes de la barre des menus sont des SVG vectoriels template de 20 points. `MenuBarIconController` remplace l’image uniquement après une écriture et une relecture matérielles réussies. Une seule tâche annulable gère le retour à l’état neutre : les actions rapprochées repoussent le délai sans empiler de timers. L’entrée directionnelle ne joue qu’au changement de sens : les crans suivants se contentent d’une micro-pulsation, ce qui évite de redémarrer l’animation à chaque écriture pendant un appui maintenu ou un glissement de curseur. Le retour à l’icône neutre est un fondu court, sans seconde pulsation. Toutes les animations sont désactivées quand macOS demande de réduire les animations.

## Construire et lancer

Ouvrir `KeyGlow.xcodeproj` dans Xcode 27.1 ou plus récent, sélectionner le schéma **KeyGlow** et la destination **My Mac**, puis lancer. En ligne de commande :

```sh
cd /Users/leo/KeyGlow
xcodebuild -project KeyGlow.xcodeproj -scheme KeyGlow -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
open build/Build/Products/Debug/KeyGlow.app
```

Le projet cible macOS 14 ou plus récent et Apple Silicon. `LSUIElement` masque l’icône du Dock au démarrage du login item ; `MainWindowController` repasse l’application en mode `.regular` quand la fenêtre principale s’ouvre, puis revient en `.accessory` à sa fermeture. La fenêtre est un `NSWindow` hébergeant `MainWindowView` (SwiftUI) ; le panneau de la barre des menus reste le `MenuBarExtra` SwiftUI au style `.window`, inchangé. Les deux packages Swift sont `KeyboardShortcuts` 3.1.0 et `MenuBarExtraAccess` 1.3.1 ; le second permet d’ouvrir le menu par raccourci, car SwiftUI ne fournit pas de commande publique de présentation de `MenuBarExtra`.

## Fenêtre principale

La fenêtre s’ouvre depuis le Finder, Spotlight, le bouton **Réglages…** de la barre des menus ou ⌘, lorsque la fenêtre est déjà au premier plan. Au démarrage à la connexion, elle ne s’ouvre pas : KeyGlow reste uniquement dans la barre des menus.

Fermer la fenêtre ne quitte pas l’application : l’icône du Dock disparaît et le panneau de la barre des menus continue de fonctionner. Une seule instance existe, garantie par LaunchServices et par le modèle partagé `AdvancedKeyGlowModel.shared`.

Les deux interfaces lisent et écrivent le même modèle et le même `HUDSettings`. Un changement de luminosité, de preset, de raccourci ou de thème HUD dans la fenêtre se répercute immédiatement dans le panneau de la barre des menus, et inversement. Le contrôleur CoreBrightness n’est pas dupliqué.

Le HUD « Menu Bar » reprend le HUD de volume de macOS : pilule sombre translucide, logo KeyGlow et segments horizontaux. Il apparaît sous l’icône de la barre des menus à chaque réglage, y compris pendant un appui maintenu sur les raccourcis augmenter/diminuer, sans recouvrir la barre des menus. C’est le thème livré par défaut ; une préférence « Minimal » héritée de la version précédente est reprise une seule fois, puis le choix reste libre dans la page **Apparence du HUD**. Le panneau `NSPanel` garde une taille fixe calculée à partir de son contenu, afin que l’ancrage ne bouge pas et que le réglage de taille s’applique correctement.

Les raccourcis de preset restent liés aux trois emplacements de la barre des menus (`profile1` à `profile3`). Réorganiser les presets change donc quel preset répond à chaque combinaison ; un preset au-delà des trois premiers n’a pas de raccourci global. Au moins un preset est toujours conservé.

La seule addition au panneau existant est le bouton **Réglages…** dans son pied de page, avec l’option de pas de 20 % ajoutée au menu déroulant. Le reste de son apparence est inchangé.

Pour le démarrage à la connexion, installer une version signée de `KeyGlow.app` dans `/Applications`, puis activer **Ouvrir à la connexion**. L’option utilise `SMAppService.mainApp` et affiche l’erreur de macOS si l’enregistrement échoue. Une application de développement non signée ou déplacée peut être refusée par Service Management.

## Tester sur le MacBook Pro M5

1. Ouvrir KeyGlow via son icône de barre des menus. La valeur affichée doit correspondre au niveau courant, y compris après les touches système de luminosité du clavier.
2. Dans une pièce où les touches sont visibles, déplacer le curseur, puis regarder **les touches du clavier**. Vérifier que les boutons `+` et `−` changent aussi leur lumière. Si l’écriture ou la relecture échoue, KeyGlow affiche une erreur et relit le niveau réel au lieu de garder la valeur demandée.
3. Cliquer sur **Éteindre le clavier**, puis **Rétablir la luminosité**. Vérifier que la valeur d’avant l’extinction revient. Refaire après avoir quitté et relancé l’application pour contrôler la persistance.
4. Déplier **Raccourcis clavier**, enregistrer quatre combinaisons distinctes, puis tester augmenter, diminuer, éteindre/rétablir et ouvrir le menu depuis une autre application. Le package signale les conflits connus avec macOS.
5. Si l’ajustement automatique est activé dans Réglages Système > Clavier, observer le clavier sous deux éclairages avant tout réglage KeyGlow. Après une écriture manuelle, macOS peut suspendre son ajustement automatique tant que KeyGlow reste ouvert. Quitter KeyGlow puis tester à nouveau sous deux éclairages. Si macOS ne reprend pas, utiliser les touches système de luminosité du clavier. KeyGlow **ne modifie pas** la préférence d’ajustement automatique, car la réactiver via l’API privée ne rétablit pas de façon fiable le contrôle ambiant.
6. Activer **Ouvrir à la connexion**, vérifier dans Réglages Système > Général > Ouverture et extensions, puis fermer la session et se reconnecter. Vérifier que KeyGlow est dans la barre des menus sans icône dans le Dock.
7. Modifier les favoris et les trois profils, puis relancer KeyGlow pour vérifier leur persistance. Tester les raccourcis associés aux profils.
8. Activer l’affichage de la jauge et du pourcentage, puis régler le niveau avec la molette placée sur l’icône de KeyGlow.
9. Tester l’extinction temporaire, la programmation horaire et les niveaux batterie/secteur. Un automatisme ne s’applique qu’à son déclenchement afin de préserver les ajustements manuels effectués ensuite.
10. Utiliser successivement le bouton `+`, le bouton `−`, le curseur, un favori et un raccourci global. Vérifier que la flèche correspond à la variation réelle, que l’icône entre en glissant vers le haut (augmentation) ou vers le bas (diminution), que des crans rapprochés ne relancent pas cette entrée, et qu’elle revient à l’icône neutre en fondu environ 700 ms après la dernière modification. Activer ensuite **Réduire les animations** dans les réglages d’accessibilité de macOS : l’icône doit encore changer de dessin, sans aucun mouvement.
11. Ouvrir la fenêtre depuis le bouton **Réglages…**, puis la fermer : l’icône du Dock doit disparaître et le panneau de la barre des menus rester utilisable. Relancer KeyGlow depuis Spotlight pendant qu’il tourne : la même fenêtre revient, sans second processus ni second élément de barre des menus.
12. Dans la fenêtre, modifier la luminosité, créer un preset, le mettre en favori et le réordonner. Vérifier que le panneau de la barre des menus reflète immédiatement ces changements, et inversement après un réglage depuis le panneau.
13. Parcourir les sept pages, choisir chacun des quatre thèmes HUD, déplacer le curseur de l’aperçu interactif et vérifier que **les touches** ne changent qu’avec **Afficher le HUD réel**, jamais avec l’aperçu simulé.
14. Activer **Ouvrir à la connexion**, redémarrer la session et vérifier qu’aucune fenêtre ne s’ouvre au login alors que l’icône de la barre des menus est présente.
15. Dans le panneau de la barre des menus, tester ⌘1 à ⌘3, ⌘0, ⌘↑, ⌘↓ puis Échap. Replier ou déplier les sections, quitter et relancer : leur état doit être conservé.
16. Faire un clic droit puis un clic avec Option sur l’icône : le menu natif doit proposer les presets, l’extinction temporaire, le HUD, Réglages et Quitter. Le clic gauche doit continuer à ouvrir le panneau SwiftUI.
17. Choisir « Preset actif » comme titre de barre des menus, puis changer de preset : le titre doit suivre le nom du preset. Revenir ensuite à « Aucun ».
18. Activer « Notifier les changements automatiques », accepter la demande de macOS, puis déclencher un changement d’alimentation : une notification locale doit apparaître.
19. Éteindre temporairement pour 15 minutes, quitter KeyGlow, le relancer : le compte à rebours doit reprendre, puis la luminosité précédente revenir à l’échéance.
20. Mettre le Mac en veille pendant que KeyGlow est ouvert, puis le réveiller : le niveau doit être relu et le curseur rester réactif.
21. Avec le thème « Menu Bar », utiliser les raccourcis augmenter/diminuer depuis une autre application, y compris en maintenant la touche : le HUD doit apparaître juste sous l’icône de KeyGlow, suivre le niveau réel et disparaître après la durée réglée, sans jamais chevaucher la barre des menus.

## Technique et limites

macOS ne propose pas d’API publique pour fixer précisément ce niveau. `KeyboardBacklightController.swift` charge dynamiquement `CoreBrightness.framework`, vérifie les classes et sélecteurs disponibles, choisit l’identifiant du clavier intégré, écrit `KeyboardBacklightBrightness` via `BrightnessSystemClient` puis relit la propriété. Une valeur lue concordante prouve que CoreBrightness a accepté le changement ; **l’observation des touches reste le test physique final**. Aucune commande `sudo`, aucun processus en boucle ni accès réseau n’est utilisé à l’exécution. Les préférences et les raccourcis sont locaux dans `UserDefaults`.

Cette API privée peut changer dans une version de macOS. Si elle manque ou si aucun clavier rétroéclairé n’est détecté, les commandes sont désactivées et une erreur est affichée. Une application fondée sur cette API privée n’est pas adaptée au Mac App Store.

L’étude de [dmartoon/MacBook-Keyboard-Backlight-Limiter](https://github.com/dmartoon/MacBook-Keyboard-Backlight-Limiter) a guidé le choix de `BrightnessSystemClient` et la prudence autour de la luminosité automatique. [rakalex/mac-brightnessctl](https://github.com/rakalex/mac-brightnessctl) documente les anciennes méthodes `KeyboardBrightnessClient` ; leur retour de succès ne garantit pas un effet matériel sur les Mac récents.

## Vérifications effectuées

Sur ce MacBook Pro M5 (`Mac17,2`), le build arm64 Debug a réussi. Une sonde du même contrôleur a lu `0`, écrit `0,75`, relu `0,75`, puis restauré `0` avec confirmation par une seconde lecture. L’ajustement automatique était désactivé lors de ce test. L’inspection visuelle des touches et le fonctionnement des sept raccourcis restent à faire dans la session graphique de l’utilisateur.
# KeyGlow
