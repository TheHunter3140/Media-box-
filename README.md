# MediaBox 0.2.0 (développement)

Lecteur multimédia iOS natif (Swift / SwiftUI), pensé pour iPhone XR (A12) : léger, économe, sans dépendance externe.
Minimum iOS 16 (référence : iOS 18.7.9). Bundle ID : `com.local.mediabox`.

## Compiler (comme Pal : GitHub Actions + XcodeGen, sans Mac)
1. Envoie tout le contenu de ce dossier à la racine d'un dépôt GitHub (le workflow est dans `.github/workflows/build.yml`).
2. Onglet Actions → « Build MediaBox (IPA non signé) » → Run workflow.
3. Télécharge l'artefact `MediaBox-unsigned-ipa`, puis signe l'IPA avec ta méthode habituelle (voir ton flux de sideloading).
4. Le job `tests` (simulateur) est facultatif : il n'empêche pas la livraison de l'IPA.

## Services (0.2.0)
Onglet **Explorer** : YouTube, SoundCloud, Spotify, Vimeo, Dailymotion, TikTok, Twitch.
- Lecture : via le site officiel dans le navigateur intégré, ou ouverture dans l'app officielle (appui long).
- Téléchargement : uniquement quand la plateforme l'autorise officiellement. SoundCloud (titres téléchargeables) et Vimeo (vidéos dont le propriétaire l'autorise) passent par leur API avec ton jeton personnel (Réglages > Services). YouTube, Spotify, TikTok, Twitch et Dailymotion : pas de téléchargement (protections / conditions d'utilisation) ; MediaBox l'explique au lieu de contourner.
- Les appels API SoundCloud/Vimeo n'ont jamais été testés avec un vrai compte.

## Design Liquid Glass
Fond dégradé + halos (sombre lumineux / clair élégant / système, réglable), dock flottant en verre (mini-lecteur + onglets).
Sur iOS 26 avec un build Xcode 26 : vrai Liquid Glass ; sinon (iOS 18 sur ton XR) matériau translucide. Le flou n'est utilisé que sur 2 éléments ; les cartes sont en verre à plat (sans flou). EcoCore coupe le flou en mode économique/thermique.

## Dossiers
Au premier lancement, MediaBox crée `Sur mon iPhone > MediaBox` (Fichiers) avec `Musique`, `Vidéos`, `Téléchargements` : tout fichier déposé est indexé automatiquement.
Les fichiers ou dossiers choisis ailleurs (iCloud Drive, etc.) sont lus **en place** via des signets de sécurité, sans copie.

## Architecture
Voir `MediaBox/` : App, Core (EcoCore, MemoryManager, ThermalMonitor, ResourceMonitor, PerformanceLogger), Playback, Library, Downloads, Browser, Storage, UI, et `Tests/`.
Stockage : JSON atomique dans Application Support (choix justifié : zéro dépendance, 1 000 fichiers ≈ 0,5 Mo ; SwiftData exigerait iOS 17).

## Limites connues (iOS / périmètre)
- YouTube : aucun téléchargement ni extraction de flux (conditions d'utilisation). Les pages s'ouvrent dans le navigateur.
- Formats : ce que décodent AVFoundation/AVPlayer (MP3, AAC, M4A, WAV, ALAC, FLAC, MP4, MOV…). MKV/AVI/OGG/OPUS non pris en charge.
- Sous-titres : pistes intégrées uniquement (pas de .srt externe).
- Le « fondu » est un fondu sortant puis entrant (pas de chevauchement de deux pistes).
- Aucune valeur de mémoire/CPU/autonomie n'est annoncée ici : elles doivent être mesurées sur iPhone XR (voir `docs/BENCHMARK.md`).
