# Protocole de benchmark — iPhone XR (à exécuter sur appareil réel)

Préparation : app installée en Release, batterie > 50 %, iPhone au repos (température nominale), bibliothèque de test de 1 000 fichiers audio, un fichier vidéo de 30 min, un fichier de test à télécharger.
Outil intégré : Réglages > Benchmark (échantillon toutes les 5 s, export CSV). Compléter avec Xcode Instruments (Allocations, Time Profiler, Energy Log) si un Mac est disponible.

| Scénario | Mémoire moy. | Pic mémoire | CPU | Fluidité | Démarrage | Réponse | Stabilité | Énergie observable |
|---|---|---|---|---|---|---|---|---|
| A. App ouverte sans activité | à mesurer | | | | | | | |
| B. Navigation dans 1 000 fichiers | à mesurer | | | | | | | |
| C. Audio 30 min | à mesurer | | | | | | | |
| D. Vidéo 30 min | à mesurer | | | | | | | |
| E. Audio + navigateur ouvert | à mesurer | | | | | | | |
| F. Téléchargement pendant l'audio | à mesurer | | | | | | | |
| G. Mode économie d'énergie | à mesurer | | | | | | | |
| H. Pression mémoire simulée | à mesurer | | | | | | | |
| I. Arrêt de lecture / libération | à mesurer | | | | | | | |

Règles : chaque scénario répété 3 fois ; noter si la mesure vient du simulateur ou de l'iPhone XR ; ne jamais remplir une case sans mesure.
