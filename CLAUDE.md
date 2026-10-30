# Contexte projet

Kinos, fork de Fladder (client Jellyfin Flutter, GPL-3.0-only — cf.
NOTICE pour l'attribution complète).
Cible : Linux desktop uniquement — CachyOS / Ryoku (Arch + Hyprland) / AMD RDNA2.

## Règles de fork

| Zone | Politique |
|---|---|
| `lib/providers/`, `lib/models/`, `lib/wrappers/` | Rester au plus près de l'amont. Corrections et ajouts seulement. |
| `lib/screens/`, `lib/widgets/` | Divergence libre. C'est notre UI. |
| `lib/arr/` (Sonarr/Radarr) | Livré. Code neuf, dossiers séparés, zéro conflit avec l'amont. |

`upstream` est un remote. Ne jamais restructurer la couche données sans raison :
chaque divergence coûte à chaque merge.

## Contraintes techniques

- **Pas de HDR.** Flutter compose en SDR 8-bit, quel que soit le compositeur
  — même Hyprland, qui gère `wp-color-management-v1` dans ses versions
  récentes, n'y change rien : la limite est en aval, pas côté protocole
  Wayland. Le tonemapping libplacebo vers SDR est définitif. Ne pas
  proposer de chemin passthrough.
- **Moteur mpv obligatoire** sur Linux (`lib/wrappers/players/lib_mpv.dart`),
  jamais MDK. Vérifier que `gpu-next` reste actif.
- Le `DeviceProfile` natif est volontairement permissif (direct play sans
  restriction de codec). Ne pas y ajouter de `codecProfiles`.

## Direction UI

Austère dans les éléments, spectaculaire dans la typographie et l'imagerie.
Le caractère vient de l'échelle typographique, du mouvement et de l'image —
jamais de l'ornement. Pas de couleur d'accent décorative.

Jetons : voir `lib/theme/app_theme.dart`. Ne jamais coder une couleur ou une
taille en dur dans un widget.

### Règles anti-mobile-first

- Aucune navigation en bas d'écran
- États de survol partout
- Menus contextuels au clic droit
- Grilles à 6–8 colonnes, jamais 3 centrées
- Aucun bouton flottant
- Raccourcis clavier visibles dans l'interface

### Règle absolue

**Tout élément interactif doit être atteignable au clavier directionnel**,
avec un focus visible. À tenir sur chaque écran, dès le premier. Une UI en
mode salon est prévue (double densité, même code).

### Bandeau teinté

La dominante du film (`heroTint`) part du bandeau d'accueil et s'étend au
fond de la zone de contenu par un dégradé vertical, résorbé à 100% avant la
fin de "Continuer à regarder" — jamais au-delà. La grille "Ajouts récents"
et tout ce qui suit restent sur `#0A0A0A` pur, pour que les jaquettes
gardent leur contraste. Toujours un dégradé de couleur, jamais un
`BackdropFilter` sur l'image : cette zone défile et change à chaque diapo.

Luminance bridée 0.06–0.22, saturation ≤ 0.40, contraste texte ≥ 4.5:1,
repli `#141414` en cas d'échec.

La barre latérale n'est pas une colonne séparée : c'est un calque
semi-transparent posé par-dessus un contenu plein cadre
(`SideNavigationRail`). Depuis la validation utilisateur du 27 octobre 2026,
la bannière et son fond teinté passent volontairement derrière la navigation,
jusqu'au bord de la fenêtre. Aucun fond noir rectangulaire derrière la capsule.
Seule la capsule garde son matériau graphite translucide et dépoli : le flou
est découpé à ses contours, jamais appliqué au bandeau. La largeur
`AdaptiveLayout.of(context).sideBarWidth` réserve l'espace des textes et actions,
pas celui de l'image ou du dégradé. Les grilles de jaquettes restent neutres.

Ne se teignent jamais non plus : anneau de focus, bouton de lecture
principal, barres de progression.

### Texte sur image

Les jetons de texte secondaire (`AppColors.textSecondary`, `context.tokens
.heroTextSecondary`) supposent un fond plat : ils n'ont pas de garantie de
contraste sur une jaquette. Sur une image (bandeaux, jaquettes), utiliser
`AppColors.textPrimary` pour le texte principal et `textPrimary` à 75 %
d'opacité pour le texte secondaire, toujours accompagnés d'un voile sombre
dégradé (`AppColors.scrim` à 0,85 en bas vers transparent, sur ~60 % de la
hauteur) qui garantit la lisibilité indépendamment de la dominante de
l'image.

## Conventions

- Riverpod pour tout l'état. Aucun appel `jellyApiProvider` depuis un widget.
- Drift pour la base locale. Toute nouvelle table passe par une migration.
- Les rapports de lecture passent par `playback_queue`, jamais en appel direct.
- Les secrets vont dans `flutter_secure_storage`, jamais dans SharedPreferences.
- Répondre en français.
- Retouches UI : privilégier le rechargement à chaud Flutter sur l’instance
  ouverte (`flutter attach` si nécessaire), sans relancer Kinos à chaque retouche.

## Périmètre

Films et séries uniquement. Hors périmètre : musique, Live TV, livres,
photos, SyncPlay, contrôle à distance.

Un serveur, plusieurs profils utilisateurs.

**Seerr (Overseerr/Jellyseerr)** est dans le périmètre : demander
l'ajout d'un titre absent de la bibliothèque, suivre le statut d'une
demande, gérer les demandes côté admin. Visible seulement si un
service Seerr est configuré sur le profil actif. Ses identifiants
(clé API, cookie de session) vivent dans `flutter_secure_storage`, au
même titre que Jellyfin et Arr — jamais dans `SharedPreferences`.

## Reste à faire

Module Arr, réécriture UI (langage visuel du projet) et renommage
Fladder → Kinos (package, identité, icônes) sont livrés.
La vue qBittorrent dédiée et la blocklist Arr sont abandonnées, hors périmètre.
Les clients et identifiants qBittorrent existants ne sont pas supprimés.

Feuille de route, priorité validée le 29 octobre 2026 :

- [ ] Stabilisation de Kinos normal : fluidité, navigation, lecteur et
      validation Seerr sur les vrais serveurs
- [ ] AniList : mapping d'identifiants d'abord
- [ ] Import Letterboxd : alimente le profil de goût, jamais les
      candidats recommandés
- [ ] Mode salon (double densité, déjà porté par le thème — reste
      l'activation/bascule de bout en bout), après stabilisation, AniList
      et Letterboxd
- [ ] Version distribuable propre, en toute fin : validation globale,
      rangement des modifications, traductions, sécurité et licences

En attente pour la version distribuable finale :

- [ ] 9 messages en français non traduits dans les autres langues
- [ ] Relecture du `NOTICE` avant publication

Dette connue :

- [ ] ~20 fichiers d'overlays/indicateurs du lecteur vidéo (volume,
      luminosité, vitesse, capture d'écran, plein écran audio,
      sélecteur de sous-titres) en couleurs/rayons bruts plutôt qu'en
      jetons du thème
- [ ] `localPin` (verrouillage local de l'app) stocké en clair sur
      disque — risque moindre qu'un secret de compte distant, mais pas
      blanchi
