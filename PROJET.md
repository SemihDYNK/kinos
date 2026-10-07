# État des lieux — Kinos

Dernière mise à jour : 2026-10-08. Ce document est un instantané factuel
pour reprendre le travail sans repartir de zéro. Il ne répète pas les
règles et contraintes de `CLAUDE.md` (zones de fork, contraintes mpv/HDR,
direction UI, conventions, feuille de route déclarée) — seulement l'état
réel du code : ce qui est implémenté, comment, et ce qui reste à faire.

## Concept de l'app

Kinos est un client Jellyfin desktop (Linux uniquement — CachyOS/Hyprland,
AMD RDNA2), fork de Fladder (GPL-3.0-only). Périmètre : **films et séries
uniquement** — musique, Live TV, livres, photos, SyncPlay et contrôle à
distance sont explicitement hors scope, bien que largement présents dans
le code hérité d'amont (jamais retiré, juste jamais utilisé par ce fork).
Un serveur, plusieurs profils utilisateurs.

Trois intégrations serveur composent l'app :
- **Jellyfin** — le cœur : authentification, bibliothèque, lecture,
  rapports de visionnage, synchronisation/téléchargement offline.
- **Arr (Sonarr/Radarr)** — gestion de la file de téléchargement, du
  calendrier de sorties et de la recherche interactive de releases,
  depuis l'app plutôt que depuis les interfaces Sonarr/Radarr natives.
- **Seerr (Overseerr/Jellyseerr)** — demander l'ajout d'un titre absent
  de la bibliothèque, suivre son statut, gérer les demandes côté admin.

Direction produit : UI desktop sans concession (pas de navigation basse,
survol partout, clic droit, raccourcis visibles, focus clavier directionnel
sur tout élément interactif dès le premier écran), austère dans les
éléments mais typographiquement affirmée. Une UI "mode salon" à double
densité est prévue, portée par le même code (cf. `AppDensity`).

## Vue d'ensemble technique

- ~1850 commits depuis le fork d'amont. Stack : Flutter 3.35.7 (fvm),
  Dart ≥3.1.3, Riverpod 2.6.1, Drift 2.28.1, auto_route 10.1.2,
  dart_mappable 4.6.0, chopper 8.3.0 (clients API générés), media_kit
  1.2.2 (via mpv), flutter_secure_storage 10.3.1, Freezed 3.1.0.
- **596 tests** passent (108 fichiers environ, en forte hausse depuis le
  dernier instantané — 412 au 23 septembre, +99 pour Seerr, +quelques
  dizaines pour la migration/résilience des identifiants). Répartition
  large : `test/arr/`, `test/recommendations/`, `test/seerr/` (8
  fichiers, 99 tests), `test/providers/` (migration et résilience des
  identifiants Jellyfin/Seerr), `test/widgets/`, `test/database/`,
  `test/models/`, `test/services/`, `test/theme/`, `test/bootstrap/`.
  **Zéro test** reste sur le système de synchronisation/téléchargement
  offline (~1300+ lignes, `sync_provider.dart` et alentours).
- `flutter analyze` : **37 issues stables**, toutes `info`/`warning`
  préexistantes (style `curly_braces_in_flow_control_structures` dans
  `service_provider.dart`, un `prefer_const_constructors`, un
  `unused_import` dans un test Arr). Origine jamais tracée précisément,
  seulement confirmées non régressives à chaque session.
- CI : `.github/workflows/checks.yaml` (lint/format), `build.yml`,
  `prepare-release.yml`, `validate-fastlane.yml` — déclenchés sur PR
  vers `develop`.
- Dépôt propre : **aucun fichier non committé** au 2026-10-08 (contraste
  avec le précédent instantané, qui listait 57 fichiers en attente — tout
  a été committé depuis, cf. section suivante).

## Travail committé depuis le dernier instantané (23 sept → 24 sept)

Dans l'ordre chronologique :

1. `a0f887d8` — lecteur vidéo : volume fiable, centrage piste/pouce de la
   barre de progression, correctifs UI barre du bas.
2. `7d6403e0` — moteur de recommandations complet + accueil enrichi
   (rangées par graine, inventaire du catalogue).
3. `634791d6` — module Arr : calendrier de sorties (vue mois/semaine).
4. `1e4c285c` — module Arr : fiche détail, recherche interactive
   auto-développée, résumé de saisons.
5. `ad06157d` — fiabilisation de la migration des données héritées au
   démarrage.
6. `12ec0f32` — correctifs desktop divers, mise à jour d'environnement.
7. `d5d26c51` → `e2a03894` (4 commits) — **sécurité Seerr** : identifiants
   migrés en coffre sécurisé, résilience du coffre indisponible,
   migration sans course ni boucle de retentatives, `CredentialsModel`
   ne montre plus le jeton Jellyfin en clair (cf. détail plus bas).
8. `95485198` — deux commentaires de code périmés corrigés
   (`playback_queue_table.dart`, `recommendation_cache_table.dart`).
9. `9a7e39f5` — `CLAUDE.md` mis à jour : module Arr marqué livré, Seerr
   ajouté explicitement au périmètre, feuille de route réécrite.
10. `ef2704ef` — 99 tests unitaires sur le module Seerr (détail plus bas).

Tous les points "Reste à faire" de l'instantané du 23 septembre concernant
le dépôt lui-même (commit du travail en cours, correction de la fuite
Seerr, mise à jour de `CLAUDE.md`) sont donc **faits**.

## Modules — ce qui est fait, et comment

### Cœur Jellyfin (auth, providers, bibliothèque, modèles)

Hérité d'amont, mature, aucun TODO trouvé dans les fichiers centraux.

- **Authentification** : `authProvider` (`lib/providers/auth_provider.dart`)
  pilote connexion/sélection de profil. Identifiants Jellyfin dans
  `SecureCredentialsStore` (`flutter_secure_storage`), migrés depuis
  `SharedPreferences` par une migration ponctuelle testée.
- **Point d'entrée réseau unique** : `jellyApiProvider` → `JellyService`
  (`lib/providers/service_provider.dart`, ~2250 lignes) — façade quasi
  exhaustive sur l'API Jellyfin. `lib/providers/` contient aussi des pans
  hors périmètre du fork (Live TV, musique, livres, photos, contrôle
  serveur) hérités et jamais retirés (zone protégée amont) — à ne pas
  confondre avec du travail actif.
- **Modèles** : `ItemBaseModel` (union `dart_mappable`) couvre tous les
  types Jellyfin ; `MovieModel`/`SeriesModel`/`EpisodeModel`/`SeasonModel`
  sont le périmètre actif. `OverviewModel` porte les métadonnées communes
  (notes, genres, chapitres, `providerIds`, `seerrUrl`).
- **Navigation** : `auto_route`, ~60 écrans routés. Navigation clavier
  directionnelle + focus visible via des composants partagés (`FocusRing`,
  `GridFocusTraveler`) réutilisés partout plutôt que réimplémentés par
  écran.
- **Bibliothèque/recherche** : `lib/screens/library_search/` — filtres
  (chips + sauvegardés), tri, bascule grille/liste, recherche à
  suggestions.
- **Écrans de détail** : film/série/saison/épisode au langage visuel du
  projet (bandeau teinté, dégradé, info technique repliable).

### Accueil et recommandations (`lib/recommendations/`)

Module autonome (zone libre), committé (`7d6403e0`).

**Pipeline** : quatre sources de candidats — bibliothèque Jellyfin vue
(`playedItemsProvider`), reprises/abandons (`resumableItemsProvider`),
bibliothèque Jellyfin non vue (`unwatchedLibraryProvider`, paginé — cf.
Performance), bibliothèque Arr (`_arrLibraryEntriesProvider`, lit
directement `ArrCredentialsStore` pour éviter une course avec les
providers de l'onglet Arr). Ces événements construisent un `TasteProfile`
pondéré (`TasteProfileBuilder`, décroissance temporelle, demi-vie 182
jours) sur des traits extraits (genre, acteur, réalisateur, studio, mot-clé,
décennie — `jellyfin_trait_extraction.dart`).

**Notation** (`RecommendationScorer`) : produit scalaire normalisé entre
le vecteur de traits binaire d'un candidat et le profil pondéré.
Correctifs calibrés :
- Diversité par trait dominant (max 2 candidats partageant leur
  justification) et par franchise (max 2 par clé de franchise).
- Justification choisie séparément du score, par spécificité de trait
  (réalisateur > mot-clé > acteur > studio > décennie > genre) parmi les
  traits à ≥75 % de la contribution maximale du candidat.
- Mots-clés rares exclus de la justification et studios trop génériques
  (>5 % de la bibliothèque, ou listés en dur) — un IDF fort sur un mot-clé
  quasi-unique ou un gros distributeur ne dit rien du goût personnel.

**Rangées produites**, dans l'ordre d'affichage : "Pour vous" (Jellyfin),
"Vous l'aviez mis de côté" (Arr seul, trié par date d'ajout), jusqu'à 4
rangées "par graine" (un trait isolé, regroupement par similarité de
Jaccard pour éviter qu'une franchise ne génère plusieurs rangées quasi
identiques — `seed_clustering.dart`, plancher de 8 candidats par graine),
puis un inventaire pur sans scoring (bien notés jamais vus, genres
étroits, décennies, longs métrages — `catalog_inventory.dart`). Un
registre de déduplication (`home_registry.dart`) réserve jusqu'à 8 ids par
rangée déjà affichée au-dessus pour garantir qu'aucun titre n'apparaît deux
fois sur la page.

**Persistance** : `RecommendationCacheEntries` (Drift, v3) fige le dernier
calcul par rangée. Seuil de recalcul à 24 h — un retour à l'accueil ne
relance jamais le calcul complet si le cache est frais.

**Non vérifié manuellement à ce jour** (reporté depuis le plan d'origine) :
lancer l'app et confirmer en conditions réelles qu'aucun titre n'apparaît
deux fois sur la page, que les rangées par graine sont bien titrées, et la
navigation clavier sur ces nouvelles rangées.

### Lecteur vidéo (`lib/screens/video_player/`, `lib/wrappers/players/`)

- Deux moteurs derrière `base_player.dart` : `lib_mpv.dart` (imposé sur
  Linux) et `lib_mdk.dart` (hérité, jamais utilisé sur la cible de ce
  fork). `media_control_wrapper.dart` fait le pont commun ;
  `pip_manager.dart`/`audio_queue_handler.dart` gèrent PIP et la file
  audio.
- Voile desktop repris au langage visuel du projet : titre/métadonnées,
  bouton Réduire et bouton Quitter séparés (auparavant confondus, Échap
  comme seul accès à la fermeture — corrigé). Infobulle de temps de la
  barre de progression reprise aux jetons du thème.
- **Statut à reconfirmer à l'écran** : le recentrage piste/pouce de la
  barre de progression et l'icône du bouton d'arrêt (committés dans
  `a0f887d8`) n'ont jamais été revérifiés visuellement depuis — à
  recontrôler avant de considérer ce point définitivement clos.
- Reste en dette de style (non traité) : ~20 fichiers d'overlays/
  indicateurs (volume, luminosité, vitesse, capture d'écran, plein écran
  audio, sélecteur de sous-titres) en couleurs/rayons bruts plutôt qu'en
  jetons du thème.
- **Mis de côté, pas commencé** : déconnexion automatique de Discord
  pendant la lecture (vérifier `pactl list sinks` avant/pendant la
  lecture avec Discord en vocal) — idée notée, aucun code.

### Module Arr — Sonarr/Radarr (`lib/arr/`)

**Livré et testé** (16 fichiers de test, aucun TODO/FIXME), et désormais
reflété comme tel dans `CLAUDE.md`. Structure : `models/`, `services/`
(`ArrApiClient` abstrait + `RadarrApiClient`/`SonarrApiClient`,
`ArrCredentialsStore` en `flutter_secure_storage`, client + coffre
qBittorrent séparés), `providers/`, `screens/` (accueil à onglets,
bibliothèque, file d'attente, calendrier, recherche interactive,
réglages), `screens/widgets/`.

Fonctionnalités livrées : file d'attente (retrait avec option "retirer du
client"/"blocklist" séparées, import forcé), calendrier (vue
semaine/mois), recherche interactive de releases (tri, tooltip de rejet,
sélection saison/épisode, grab), fiche détail (surveiller, recherche
auto/interactive, édition profil qualité/dossier racine/monitored,
suppression), bibliothèque (grille paginée, tri/filtre), réglages (URL +
clé API par service, test de connexion, config qBittorrent). Lien avec
Jellyfin : recherche par titre normalisé + année (pas d'ID externe exposé
par l'API générée), best-effort, alimente aussi la redirection Jellyfin de
la rangée "Vous l'aviez mis de côté".

**Décision actée** (`CLAUDE.md`) : la blocklist Arr est abandonnée, hors
périmètre — ce n'est plus un manque à combler, c'est tranché.

Manque réellement : **vue qBittorrent dédiée** (client et identifiants
déjà en place, seule la vue liste/progression des torrents manque).

### Module Seerr — Overseerr/Jellyseerr (`lib/seerr/`, `lib/screens/seerr/`)

**Dans le périmètre déclaré de `CLAUDE.md` depuis le 2026-09-24**
(tranché — ce n'était plus "à décider" comme au précédent instantané).
Architecture : client Chopper/Swagger généré (même pattern que le client
Jellyfin, `SeerrChopperService`/`SeerrJsonConverter`), un seul service
actif par compte (pas de multi-instance comme Arr). Deux entrées dans la
barre latérale ("Découverte", "Demandes"), visibles seulement si un
service Seerr est configuré sur le profil actif
(`seerrCredentials?.isConfigured`).

**Sécurité — corrigée** (`d5d26c51` → `e2a03894`) : les identifiants
(`apiKey`, `sessionCookie`) vivent désormais dans `flutter_secure_storage`
via `SeerrCredentialsStore` (clé composite `seerr:serverId:userId`), même
schéma que Jellyfin/Arr. Migration ponctuelle depuis l'ancien stockage en
clair, avec les mêmes garanties que la migration Jellyfin après durcissement
dans le même lot : écriture → relecture de vérification → effacement du
texte en clair seulement après succès ; jamais de perte de données si le
coffre est indisponible (comptes affectés simplement exclus de l'écriture
du coffre jusqu'au prochain lancement) ; migration mémoïsée pour n'être
tentée qu'une fois par session même en cas d'échec durable.
`SeerrCredentialsModel.toString()` ne montre plus la valeur des secrets
(présence seulement), idem pour `CredentialsModel` côté Jellyfin.

**Tests — faits** (`ef2704ef`, 99 tests, 8 fichiers `test/seerr/`) :
mapping statut/média, décodage JSON sur fixtures réalistes (synthétiques,
marquées comme telles — 3 à remplacer par de vraies captures), construction
des en-têtes d'authentification et de l'URL, gestion des erreurs HTTP/
réseau, construction du corps des requêtes de demande (film/série),
extraction des identifiants externes (tmdbId/tvdbId/imdbId — base du futur
mapping AniList), cas de champ inattendu par modèle principal.

**Bug découvert en écrivant ces tests, documenté, non corrigé** — voir
section Bugs connus.

**Lot "découverte hors catalogue" : en cours de conception, interrompu.**
Un prompt de planification ("Phase 1 — plan sans code") est en cours dans
une autre conversation, coupé en plein point 7 — à y reprendre, pas dans
celle-ci. Rien n'est encore implémenté pour ce lot.

### Persistance locale (Drift, `lib/models/syncing/`)

`AppDatabase`, schéma v3, 5 tables : `DatabaseItems` (cache Jellyfin
synchronisé/téléchargé), `PlaybackQueue` (outbox des rapports de
lecture), `PaletteCache` (couleur dominante de jaquette), `Settings`
(clé/valeur scopée), `RecommendationCacheEntries` (dernier calcul de
recommandations, scope explicite par `userId`). Migrations v1→v2→v3
testées, schémas exportés dans `drift_schemas/`.

**Rapports de lecture** : `PlaybackReportQueueWorker`
(`@Riverpod(keepAlive: true)`) draine `PlaybackQueue` en continu (timer
30 s + retour de connectivité + rattrapage au démarrage). Backoff
exponentiel par entrée (base 5 s, doublé par tentative, plafonné à 5 min,
testé). `PlaybackConflictResolver` réconcilie avec l'état serveur avant
envoi.

**Secrets** : trois coffres séparés désormais (`SecureCredentialsStore`
pour Jellyfin, `ArrCredentialsStore` pour Radarr/Sonarr + qBittorrent,
`SeerrCredentialsStore` pour Seerr depuis `d5d26c51`), même schéma de clé
composite, tous sur `flutter_secure_storage`. **Exception restante :
`localPin`** (verrouillage local de l'app, champ d'`AccountModel`) —
toujours en clair dans `SharedPreferences`, jamais traité (risque jugé
moindre qu'un secret de compte distant, mais pas blanchi).

### Synchronisation / téléchargement offline (`lib/providers/sync_provider.dart` et alentours)

Système hérité d'amont, générique multi-médias (y compris musique, hors
périmètre déclaré), fonctionnel sur la cible desktop de ce fork (chemin de
sauvegarde explicitement branché sur Windows/Linux/macOS via
`clientSettingsProvider.syncPath`). `SyncNotifier` (~1330 lignes) pilote
ajout/suppression/rafraîchissement ; le téléchargement effectif passe par
`background_downloader` ; état persisté dans les colonnes
`DatabaseItems.path`/`videoFileName`/`fileSize`/`syncing`. Écrans dédiés
sous `lib/screens/syncing/`. **Toujours aucun test.** Le point exact qui
fait lire un fichier local plutôt que le flux réseau au moment de la
lecture reste à retracer.

### Thème / design system (`lib/theme/app_theme.dart`)

Un seul thème sombre. Jetons : `AppColors` (`background` #0A0A0A,
`surface` #141414, `surfaceHigh` #1C1C1C — attention, `ColorScheme.dark`
mappe `colorScheme.surface` sur `AppColors.background`, pas sur
`AppColors.surface`), `AppSpacing` (xxs 4 → md 16), `AppRadii` (control 4,
card 8, sheet 12), `AppTypography` (échelle display/section/card/body/
meta, rapport 1:3 entre titre d'écran et métadonnées — principal levier
de caractère du projet), `AppDensity` (bureau vs salon, facteur 1.35 sur
cibles tactiles/espacements en mode salon — thème prêt, bascule de bout en
bout pas encore implémentée). `AppTokens` porte la teinte de bandeau
courante et son texte secondaire dérivé.

## Décisions d'architecture transversales

- **Riverpod pour tout l'état, `lib/providers/` protégé** : aucun appel
  API direct depuis un widget. Chaque source de données lente est un
  `FutureProvider.autoDispose` séparé, combiné dans un provider de plus
  haut niveau.
- **`ref.keepAlive()` après succès, jamais avant** : pour qu'un calcul
  coûteux ne soit fait qu'une fois par session, sans garder en mémoire un
  état d'échec qui empêcherait un vrai retry.
- **Secrets dans `flutter_secure_storage`, jamais `SharedPreferences`,
  clé composite systématique** (`serverId:userId`, `arr:<service>`,
  `seerr:serverId:userId`) — appliqué et testé pour Jellyfin, Arr/
  qBittorrent et désormais Seerr. Reste l'exception `localPin` (ci-dessus).
- **Toute indirection réseau différée passe par une file Drift, jamais
  fire-and-forget** : `PlaybackQueue` pour les rapports de lecture,
  `background_downloader` + `DatabaseItems` pour les téléchargements.
- **Diversité calculée sur le même trait que la justification affichée**
  (recommandations) plutôt que deux calculs indépendants qui pourraient
  diverger.
- **Grilles à hauteur de cellule explicite (`mainAxisExtent`), jamais
  `childAspectRatio`, dès qu'une cellule porte un libellé sous l'image**
  — `childAspectRatio` reconverti en pixels par le delegate peut tomber
  en-deçà de la hauteur réelle du libellé → bande de débordement visible.
- **Un test qui révèle un bug dans le code existant se documente, ne se
  corrige jamais en silence** — convention établie pendant le lot de
  tests Seerr (cf. Bugs connus) : rapporter fichier:ligne, comportement
  observé/attendu, laisser la décision de correction à l'humain.

## Bugs connus non corrigés

1. **`SeerrJsonConverter.convertResponse` plante au lieu de renvoyer un
   body `null` proprement** (`lib/seerr/seerr_json_converter.dart:60` et
   `:75`). Cause : `Response.copyWith` de chopper (`body ?? (this.body as
   NewBodyType?)`) ne distingue pas "paramètre omis" de "paramètre `null`
   explicite" — l'ancien body (la chaîne JSON brute) est recasté sur le
   nouveau type et lève un `TypeError` qui masque l'erreur de décodage
   initiale. Portée réelle, précisée par les tests (`ef2704ef`) : **n'est
   atteint que sur une réponse 2xx** dont le corps échoue au décodage
   (corps vide, champ malformé) et dont le type de retour est concret —
   `approveRequest`, `createRequest`/`requestMovie`/`requestSeries`,
   `updateMediaStatus` sont exposés ; `logout`/`deleteRequest`/
   `deleteMedia`/`deleteMediaFile` (`Response<dynamic>`) ne le sont pas,
   un cast vers `dynamic` ne lève jamais. Pas de capture réelle confirmant
   qu'un de ces endpoints renvoie effectivement un corps vide en pratique.
   Impact UI si déclenché : silencieux pour "Approuver une demande"
   (`seerr_details_provider.dart:236`, aucun try/catch) ; visible mais
   moche pour "Marquer disponible/indisponible" (trace brute affichée
   comme message d'erreur) ; sans impact pour "Demander un titre" (passe
   par `.apiResult`, qui encapsule tout dans un try/catch).
2. **Aucun `errorConverter` configuré sur le `ChopperClient` Seerr** —
   consequence connexe du point 1 : pour tout statut HTTP non-2xx
   (401/403/409/502…), `response.error` est la chaîne JSON brute non
   décodée, jamais le champ `"message"` extrait proprement. Le message
   finit techniquement lisible par l'utilisateur (`ApiError.toString()` →
   snackbar `KinosSnack.showResponse`) mais noyé dans du JSON non nettoyé,
   ex. `An error occurred: Exception: (409) Bad Request:
   {"message":"Request quota exceeded"}`. Un timeout côté client Seerr
   pourrait être ajouté sans toucher aux zones protégées (`lib/util/
   seerr_http_client.dart`/`seerr_http_client_web.dart` sont libres) —
   actuellement **aucun timeout n'existe**, une requête Seerr qui ne
   répond jamais bloque indéfiniment.
3. **`localPin` stocké en clair** sur disque (`SharedPreferences`, via
   `AccountModel`) — risque moindre qu'un secret de compte distant, mais
   pas blanchi. Non traité.
4. **Dette de style dans le lecteur vidéo** — ~20 fichiers d'overlays/
   indicateurs en couleurs et rayons bruts plutôt qu'en jetons du thème.
   Identifié, délibérément non traité, chantier à part entière si
   souhaité.
5. **Zéro test sur la synchronisation/téléchargement offline**
   (`sync_provider.dart` et alentours, ~1300+ lignes). Pas un bug en soi,
   mais une surface sans filet pour toute modification future.
6. **Statut visuel non reconfirmé** : le recentrage piste/pouce de la
   barre de progression vidéo et l'icône du bouton d'arrêt (`a0f887d8`)
   n'ont jamais été revérifiés à l'écran depuis leur commit.

## Mesures de performance actuelles

- **Requête bibliothèque "non vus" (recommandations)** : pagination en
  pages de 200 + concurrence 4 → ~28-29 s (plancher réseau mesuré, pas un
  goulot côté app). Réglage retenu dans
  `recommendation_providers.dart:110-112`.
- **Calcul de notation lui-même** (hors réseau) : de l'ordre de la
  dizaine de millisecondes — négligeable face au coût réseau, ce qui a
  motivé la duplication du calcul plutôt qu'un couplage entre
  `recommendationResultProvider` et `homeCatalogResultProvider`.
- **Seuil de recalcul des recommandations** : 24 h — un retour à l'accueil
  dans cette fenêtre affiche directement le cache Drift.
- Aucun autre benchmark automatisé (démarrage à froid, première frame,
  mémoire) n'existe dans le dépôt à ce jour.

## Reste à faire

Feuille de route produit (ordre, justification) : voir `CLAUDE.md` §
Feuille de route — ce document ne la duplique pas. Rappel de l'ordre
acté : lot Seerr (découverte hors catalogue) → AniList (mapping
d'identifiants d'abord) → import Letterboxd (alimente le profil de goût,
jamais les candidats recommandés) → mode salon (en dernier).

Ouverts côté code, dans un ordre de priorité suggéré :

- **Lot Seerr "découverte hors catalogue"** — conception interrompue dans
  une autre conversation (point 7 d'un plan en cours), à reprendre là-bas.
  Le prompt de vérification préalable (bug du corps vide, messages
  d'erreur lisibles, timeout client — cf. Bugs connus 1-2) conditionne ce
  lot et a déjà été traité par ce document.
- **Fixtures Seerr réelles** à capturer (`discover/trending`,
  `movie/<id>`, `tv/<id>`, `requests`) pour remplacer les 3 fixtures
  synthétiques identifiées dans `test/fixtures/seerr/README.md`, avec
  nettoyage des champs personnels avant capture.
- **Décider du bug `SeerrJsonConverter`** (Bugs connus 1) : corriger
  (remplacer `response.copyWith(body: null, ...)` par une construction
  directe de `Response`), ou documenter plus largement et laisser tel
  quel — impact limité à 3 endpoints, aucune preuve d'occurrence réelle à
  ce jour.
- **Timeout client Seerr** (Bugs connus 2) — faisable sans toucher aux
  zones protégées.
- **Reconfirmer à l'écran** le recentrage piste/pouce et l'icône du bouton
  d'arrêt du lecteur vidéo (Bugs connus 6).
- **Vérification manuelle du module recommandations** (jamais faite,
  reportée depuis le lot d'origine) : absence de doublon sur la page
  d'accueil, titres des rangées par graine, navigation clavier.
- **`localPin` en clair** (Bugs connus 3) — à traiter ou à documenter
  comme risque accepté.
- **Dette de style du lecteur vidéo** (Bugs connus 4) — chantier à part
  si souhaité.
- **Tests sur la synchronisation/téléchargement offline** (Bugs connus
  5) — avant toute modification non triviale de cette zone.
- **Vue qBittorrent dédiée** (client et identifiants déjà en place, la
  vue manque).
- **Déconnexion Discord au play** — idée notée, mis de côté, aucun code
  (vérifier `pactl list sinks` avant/pendant lecture avec Discord en
  vocal).
- **9 messages non traduits** et **relecture du `NOTICE`** avant
  publication (déjà notés dans `CLAUDE.md` § En attente).
