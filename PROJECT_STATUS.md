# État du projet (0.1.0)

## Écrit (code présent)
Toutes les sections du cahier des charges ont une première implémentation.

## NON vérifié
- Aucune compilation n'a été exécutée (environnement Linux sans Xcode/Swift). Des erreurs de compilation sont probables : le premier build GitHub Actions les révélera ; envoie-moi `build.log`.
- Aucun test exécuté. Aucune mesure mémoire/CPU/autonomie : le plafond de 100 Mo n'est PAS validé.
- À valider sur iPhone XR : PiP après fermeture de l'écran vidéo, reprise audio après interruption/changement de route, téléchargements en arrière-plan, relancement après fermeture de l'app.

## Écarts assumés
- Ajout de `PlaybackController.swift`, `MediaModels.swift`, `AppSettings.swift`, `Theme.swift` (non listés dans la structure indicative) pour garder les fichiers cohérents.
- JSON à la place de SQLite/SwiftData.
- Pas d'icône d'app pour le moment.


## Révision 0.1.1 — préparation CI et identité visuelle

- Ajout d'une icône d'application dans `MediaBox/Resources/Assets.xcassets/AppIcon.appiconset/`.
- Activation de l'asset catalog `AppIcon` dans `project.yml`.
- Workflow GitHub Actions renforcé : journal de compilation et de tests conservé comme artefact, résumé des erreurs dans l'exécution, création/commentaire automatique d'une issue GitHub en cas d'échec.
- Les tests sont maintenant bloquants pour la publication d'une release.
- Une préversion GitHub `nightly` est mise à jour à chaque push réussi sur `main` ; une release stable est créée lorsqu'un tag `v*` est poussé. Dans les deux cas, build et tests doivent réussir.
- L'IPA reste non signé : aucune installation automatique sur iPhone ni publication App Store n'est réalisée par ce workflow.

**Important :** cette révision n'est pas déclarée compilée. Le conteneur d'audit ne dispose pas de Xcode ni du SDK iOS. La validation finale doit être faite par GitHub Actions sur macOS, puis sur un iPhone XR réel.


## Révision 0.1.2 — correction ciblée du build
- Corrigé `BrowserManager.reload()` pour supprimer l'incompatibilité de types dans l'opérateur ternaire signalée par GitHub Actions.
- Cette correction est fondée sur le diagnostic de build fourni par l'utilisateur.
- Compilation non exécutée localement : elle doit être confirmée par une nouvelle exécution GitHub Actions.


## 0.2.0 — état de la refonte
- Accueil SwiftUI refait avec cartes des sept plateformes, raccourcis vers Bibliothèque/Navigateur/Téléchargements, statistiques et contenus récents.
- Sélecteur de thème persistant : automatique, clair, sombre.
- Les services sont pour l'instant des points d'entrée vers leurs sites officiels dans WKWebView. Ce n'est pas une intégration API/SDK complète et l'authentification dépend des sites.
- Téléchargement : les liens directs autorisés continuent d'être gérés par MediaBox. Les téléchargements protégés/abonnements des plateformes ne sont pas extraits.
- Pas de build Xcode ni test simulateur effectué dans cet environnement. Vérifier le build sur GitHub Actions puis le comportement de chaque site sur iPhone XR.
