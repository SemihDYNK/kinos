# Top bar Kinos — validation du 28 octobre 2026

Maquette validée dans le chat, intégrée à la navigation desktop existante.

- Capsule graphite dépolie : À la une, Films, Séries, Découvrir et Bibliothèques.
- Découvrir reste conditionné à la configuration Seerr du profil actif.
- Bibliothèques films/séries générées depuis les vues Jellyfin.
- Accueils de type/bibliothèque : bandeau, reprises et ajouts récents filtrés côté serveur ; accès au catalogue complet.
- À la une conserve les rangées configurées de l’accueil actuel.
- Recherche superposée : Ctrl K, saisie temporisée, résultats films/séries, états chargement/vide/erreur, réessai, Échap, accès directionnel aux résultats. Sélection rapide de 24 titres, lien vers tous les résultats.
- Rail allégé : Demandes et Arr, réglages et profil. La top bar reste accessible depuis les outils.
- Sélection et requêtes isolées par profil. Reprises filtrées aussi localement pour exclure les titres non commencés/terminés.
- Le mode salon utilisant l’ancienne navigation haute conserve cette dernière.

## Preuves

Capture réelle après rechargement à chaud : `references/kinos-topbar-linux.png`.
Le seuil historique « tablette » couvre les fenêtres de 600–1919 pixels ; le chrome desktop s’y applique aussi sur Linux.

712 tests réussis, dont filtres serveur, changement de profil, reprises, bibliothèque dynamique,
onglets, retour des outils, recherche superposée, Ctrl K, Échap, parcours aux flèches,
texte agrandi et accès aux résultats au-delà de la sélection rapide.
Références visuelles du rail actualisées après inspection de la différence.
Analyse : 37 diagnostics préexistants. Compilation Linux debug réussie. `git diff --check` réussi.

Prowl indisponible : aucune workspace `.prowl` initialisée. Aucune réinitialisation effectuée.
Les interactions ont été vérifiées par tests ; le contrôle visuel sur serveur réel porte sur l’accueil.

## Retouche validée — capsule et bibliothèques

Capsule centrée à largeur intrinsèque (défilement des onglets si nécessaire).
Libellés alignés verticalement ; soulignement actif superposé sans déplacement du texte.
Le menu Bibliothèques ouvre directement `ViewModel.navigateToView`, donc la grille filtrée complète.
Tests ciblés réussis, analyse inchangée à 37 diagnostics, rechargement à chaud et capture réelle contrôlée.

## Bibliothèques déplacées dans la sidebar

Le menu Bibliothèques est retiré de la top bar. Le rail affiche une entrée
par bibliothèque films/séries du serveur, ouvrant directement sa grille.
13 tests ciblés réussis, dont navigation depuis l’icône au clavier.
Rechargement à chaud effectué. Aucune refonte des animations à cette étape.
