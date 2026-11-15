# Changelog

## 0.1.0 — première version complète (non compilée ni testée sur appareil)
Ajouts : tout le projet (46 fichiers Swift), project.yml (XcodeGen), workflow GitHub Actions, tests unitaires, docs.
Fonctions : lecteur audio (AVAudioEngine, égaliseur 10 bandes, vitesse, fondu, minuteur de sommeil, Now Playing, interruptions, reprise), lecteur vidéo (AVPlayerViewController, PiP, luminosité/volume, vitesse, reprise, audio seul), bibliothèque (accès direct par signets, indexation par lots, métadonnées, playlists, playlists intelligentes, doublons), navigateur WKWebView, téléchargements (session d'arrière-plan, pause/reprise, file, historique, doublons), EcoCore à 4 profils, Centre mémoire et stockage, enregistreur de benchmark (CSV).


## 0.1.2 — correction de compilation
- `MediaBox/Browser/BrowserManager.swift` : remplacement de l'expression ternaire de `reload()` par un `if/else` explicite. Les branches n'ont plus à partager un type de retour (`Void?` contre `WKNavigation?`).
- Correction ciblée sur l'erreur rapportée par GitHub Actions. Les autres erreurs éventuelles ne sont pas encore connues.


## 0.2.0 — refonte visuelle et hub de services
- Refonte de l'accueil avec hero Liquid Glass, cartes de services, raccourcis, statistiques et reprise de lecture.
- Ajout d'un catalogue des sept services demandés : YouTube, SoundCloud, Spotify, Vimeo, Dailymotion, TikTok et Twitch. Les cartes ouvrent les sites officiels dans le navigateur intégré.
- Ajout du choix d'apparence automatique / claire / sombre, mémorisé dans les réglages. Transparence activée par défaut, sous réserve des politiques EcoCore.
- Les téléchargements restent limités aux fichiers directs et contenus explicitement exportables/téléchargeables. Pas d'extraction de flux, de contournement DRM ou de copie des contenus hors ligne des abonnements.
- Les SDK, OAuth et intégrations natives propres à chaque plateforme ne sont pas encore implémentés : ils nécessitent des accès/API/conditions propres à chaque fournisseur.
