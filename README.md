# MediaBox 0.1.0 (développement)

Lecteur multimédia iOS natif (Swift / SwiftUI), pensé pour iPhone XR (A12) : léger, économe, sans dépendance externe.
Minimum iOS 16 (référence : iOS 18.7.9). Bundle ID : `com.local.mediabox`.

## Compiler (comme Pal : GitHub Actions + XcodeGen, sans Mac)
1. Envoie tout le contenu de ce dossier à la racine d'un dépôt GitHub (le workflow est dans `.github/workflows/build.yml`).
2. Onglet Actions → « Build MediaBox (IPA non signé) » → Run workflow.
3. Télécharge l'artefact `MediaBox-unsigned-ipa`, puis signe l'IPA avec ta méthode habituelle (voir ton flux de sideloading).
4. Le job `tests` (simulateur) est facultatif : il n'empêche pas la livraison de l'IPA.

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


## CI, erreurs et publication

- Chaque push sur `main` déclenche une compilation iOS et les tests sur simulateur.
- Les journaux `build.log` et `test.log` sont conservés comme artefacts.
- En cas d'échec, le workflow crée une issue GitHub ou ajoute un commentaire à l'issue d'échec déjà ouverte.
- Chaque push réussi sur `main` met à jour automatiquement la préversion GitHub `nightly` après réussite du build et des tests.
- Pour publier une version stable, pousser un tag versionné, par exemple `v0.1.1`. La release stable ne sera créée qu'après réussite de la compilation et des tests.
- L'IPA publié est **non signé**. Pour une installation directe, il faut encore le signer avec un certificat et un profil valides. La publication App Store nécessite un flux Apple Developer distinct.
