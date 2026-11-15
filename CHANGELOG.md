# Changelog

## 0.2.0 — refonte (non compilée ni testée)
- Nouveau design Liquid Glass (thème sombre/clair/système, halos, dock flottant, cartes en verre à plat).
- Onglet Explorer + module Services (7 plateformes), lecture officielle, téléchargement par API officielle (SoundCloud, Vimeo, jeton dans le Trousseau), refus expliqué pour les plateformes protégées.
- Moteur audio/vidéo, bibliothèque, EcoCore et téléchargements inchangés.
- Tests ajoutés : ServiceTests.


## 0.1.0 — première version complète (non compilée ni testée sur appareil)
Ajouts : tout le projet (46 fichiers Swift), project.yml (XcodeGen), workflow GitHub Actions, tests unitaires, docs.
Fonctions : lecteur audio (AVAudioEngine, égaliseur 10 bandes, vitesse, fondu, minuteur de sommeil, Now Playing, interruptions, reprise), lecteur vidéo (AVPlayerViewController, PiP, luminosité/volume, vitesse, reprise, audio seul), bibliothèque (accès direct par signets, indexation par lots, métadonnées, playlists, playlists intelligentes, doublons), navigateur WKWebView, téléchargements (session d'arrière-plan, pause/reprise, file, historique, doublons), EcoCore à 4 profils, Centre mémoire et stockage, enregistreur de benchmark (CSV).
