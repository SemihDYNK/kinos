# État des lieux — Kinos

Dernière mise à jour : 2026-09-23. Ce document est un instantané factuel
pour reprendre le travail sans repartir de zéro. Il ne répète pas les
règles et contraintes de `CLAUDE.md` (zones de fork, contraintes mpv/HDR,
direction UI, conventions) — seulement l'état réel du code.

## État du dépôt — travail non committé

Le dernier commit (`9246977b`, "docs: attribution du fork, NOTICE,
README, CLAUDE.md") est suivi d'un volume important de travail non
committé (57 fichiers modifiés/nouveaux à la racine du repo, hors
build/générés) :

- **Le module recommandations entier** (`lib/recommendations/`, tous les
  fichiers listés en section ci-dessous) — non committé.
- **Rangées par graine + inventaire du catalogue** (`seed_row_section.dart`,
  `catalog_inventory_section.dart`, `recommendation_tile.dart`,
  `recommendation_row_section.dart`) — non committé.
- **Module Arr — calendrier** (`arr_calendar_*`) — non committé.
- **Quatre corrections de cette session** (voir « Bugs connus » plus bas
  pour ce qu'elles corrigent) : désynchronisation curseur de volume
  (`floating_player_bar.dart`, `music_player_bar_content.dart`),
  débordement de grille d'épisodes (`episode_details_list.dart`,
  `continue_watching_section.dart`), bouton d'arrêt + infobulle de
  progression du lecteur (`video_player_controls.dart`,
  `video_progress_bar.dart`), retrait de l'affichage de la justification
  des jaquettes (les 3 fichiers de rangées ci-dessus).
- Une migration Drift v2→v3 (`recommendation_cache_table.dart`,
  `drift_schemas/drift_schema_v3.json`) et son câblage dans
  `AppDatabase`/`database_item.dart`.

`flutter analyze` est propre et `flutter test` passe (412 tests) sur cet
état non committé. Rien ne bloque un commit, c'est simplement resté en
plusieurs lots de travail non scindés/livrés.

## Vue d'ensemble

- ~1850 commits depuis le fork d'amont (Fladder). Stack : Flutter
  3.35.7 (fvm), Dart ≥3.1.3, Riverpod 2.6.1, Drift 2.28.1, auto_route
  10.1.2, dart_mappable 4.6.0, chopper 8.3.0 (clients API générés),
  media_kit 1.2.2 (via mpv), flutter_secure_storage 10.3.1, Freezed
  3.1.0.
- 412 tests (44 fichiers) passent. Répartition : `test/arr/` (16),
  `test/recommendations/` (15), `test/widgets/` (4), `test/database/`
  (2), `test/providers/` (2), `test/bootstrap/`, `test/models/`,
  `test/services/`, `test/theme/` (1 chacun). **Zéro test** sur le
  module Seerr et sur le système de synchronisation/téléchargement
  offline (~1650 lignes à eux deux).
- CI : `.github/workflows/checks.yaml` (lint/format), `build.yml`,
  `prepare-release.yml`, `validate-fastlane.yml` — déclenchés sur PR
  vers `develop`.
- Renommage Fladder → Kinos et nouveau logo : **faits**, contrairement à
  ce que dit encore `CLAUDE.md` (`Reste à faire`) — package `kinos`,
  identité Linux `app.kinos`, migration des comptes existants
  (`lib/bootstrap/legacy_migration.dart`), jeu d'icônes complet dans
  `icons/production/` (desktop, adaptive, .ico, store). Seuls les
  fichiers sources historiques (`assets/Icon.svg`,
  `assets/fladder_icon*.afphoto`) gardent encore le nom d'origine — pas
  utilisés en sortie de build.

## Modules — ce qui est fait

### Cœur Jellyfin (auth, providers, bibliothèque, modèles)

Hérité d'amont, mature, aucun TODO trouvé dans les fichiers centraux.

- **Authentification** : `authProvider` (`lib/providers/auth_provider.dart`)
  pilote connexion/sélection de profil ("un serveur, plusieurs profils").
  Identifiants Jellyfin dans `SecureCredentialsStore`
  (`flutter_secure_storage`), migrés depuis `SharedPreferences` par une
  migration ponctuelle testée (`shared_provider_credentials_migration_test.dart`).
- **Point d'entrée réseau unique** : `jellyApiProvider` →
  `JellyService` (`lib/providers/service_provider.dart`, 2248 lignes) —
  façade quasi exhaustive sur l'API Jellyfin. Toute la couche `lib/providers/`
  contient aussi des pans entiers hors périmètre du fork (Live TV,
  musique, livres, photos, contrôle serveur, Seerr) hérités et jamais
  retirés (zone protégée amont) — à ne pas confondre avec du travail
  actif.
- **Modèles** : `ItemBaseModel` (union `dart_mappable`) couvre tous les
  types Jellyfin ; `MovieModel`/`SeriesModel`/`EpisodeModel`/`SeasonModel`
  sont le périmètre actif, le reste (livre, album, chaîne…) est hérité.
  `OverviewModel` porte les métadonnées communes (notes, genres,
  chapitres, `providerIds`, `seerrUrl`).
- **Navigation** : `auto_route`, ~60 écrans routés. Navigation clavier
  directionnelle + focus visible via des composants partagés
  (`FocusRing`, `GridFocusTraveler`) réutilisés partout plutôt que
  réimplémentés par écran.
- **Bibliothèque/recherche** : `lib/screens/library_search/` — filtres
  (chips + sauvegardés), tri, bascule grille/liste, recherche à
  suggestions. État porté par des providers dédiés
  (`library_filters_provider`, etc.), corrigé cette année pour survivre
  à la navigation et s'isoler par destination (cf. historique git
  `f67b4026`, `a850f7f8`).
- **Écrans de détail** : film/série/saison/épisode réécrits au langage
  visuel du projet (bandeau teinté, dégradé, info technique repliable).

### Accueil et recommandations (`lib/recommendations/`)

Module le plus récent et le plus dense, entièrement autonome (zone
libre au sens du fork). Non committé (cf. plus haut).

**Pipeline** : quatre sources de candidats — bibliothèque Jellyfin vue
(`playedItemsProvider`), reprises/abandons (`resumableItemsProvider`),
bibliothèque Jellyfin non vue (`unwatchedLibraryProvider`, paginé —
cf. Performance), bibliothèque Arr (Radarr/Sonarr, `_arrLibraryEntriesProvider`,
lit directement `ArrCredentialsStore` pour éviter une course avec les
providers de l'onglet Arr). Ces événements construisent un
`TasteProfile` pondéré (`TasteProfileBuilder`, décroissance temporelle,
demi-vie 182 jours) sur des traits extraits (genre, acteur,
réalisateur, studio, mot-clé, décennie — `jellyfin_trait_extraction.dart`).

**Notation** (`RecommendationScorer`) : produit scalaire normalisé
entre le vecteur de traits binaire d'un candidat et le profil pondéré.
Correctifs calibrés :
- Diversité par trait dominant : max 2 candidats partageant leur
  justification (`maxPerDominantTrait = 2`).
- Diversité par franchise : max 2 candidats par clé de franchise
  (`maxPerFranchise = 2`, attrape les suites dont les traits dominants
  diffèrent).
- Justification choisie séparément du score, par spécificité de trait
  (réalisateur > mot-clé > acteur > studio > décennie > genre) parmi
  les traits à ≥75 % de la contribution maximale du candidat
  (`comparableTolerance = 0.25`).
- Mots-clés rares exclus de la justification (`minKeywordDocFrequencyForJustification = 6`)
  et studios trop génériques (>5 % de la bibliothèque, ou listés en dur —
  Netflix, Disney, Warner…) — un IDF fort sur un mot-clé quasi-unique ou
  un gros distributeur ne dit rien du goût personnel.

**Rangées produites** : "Pour vous" (Jellyfin) et "Vous l'aviez mis de
côté" (Arr seul, trié par date d'ajout — *pas* un classement de goût),
puis jusqu'à 4 rangées "par graine" (un trait isolé, regroupement par
similarité de Jaccard pour éviter qu'une franchise ne génère plusieurs
rangées quasi identiques — `seed_clustering.dart`, plancher de 8
candidats par graine), puis un inventaire pur sans scoring (bien notés
jamais vus, genres étroits, décennies, longs métrages —
`catalog_inventory.dart`). Un registre de déduplication
(`home_registry.dart`) réserve jusqu'à 8 ids par rangée déjà affichée
au-dessus pour garantir qu'aucun titre n'apparaît deux fois sur la
page.

**Persistance** : `RecommendationCacheEntries` (Drift, v3) fige le
dernier calcul par rangée (titre, image, justification traduite,
position). Seuil de recalcul à 24 h
(`recommendationRecomputeNeededProvider`) — un retour à l'accueil ne
relance jamais le calcul complet si le cache est frais ; action
manuelle "Recalculer les recommandations" dans les réglages sinon.

**Affichage** : la justification ("Produit par X", "Parce que vous avez
regardé Y") ne s'affiche plus au survol des jaquettes depuis cette
session — retirée de `RecommendationTile` et de ses call sites, le
calcul moteur (diversité + titre des rangées par graine) est intact.

### Lecteur vidéo (`lib/screens/video_player/`, `lib/wrappers/players/`)

- Deux moteurs derrière `base_player.dart` : `lib_mpv.dart` (imposé sur
  Linux) et `lib_mdk.dart` (hérité, jamais utilisé sur la cible de ce
  fork). `media_control_wrapper.dart` fait le pont commun ;
  `pip_manager.dart`/`audio_queue_handler.dart` gèrent PIP et la file
  audio.
- Voile desktop repris au langage visuel du projet (`video_player_controls.dart`,
  `desktopTopBar`/`desktopBottomBar`) : titre/métadonnées, bouton
  Réduire, et depuis cette session un bouton Quitter séparé à côté (les
  deux actions étaient auparavant confondues, avec Échap comme seul
  accès à la fermeture).
- Infobulle de temps de la barre de progression (`video_progress_bar.dart`,
  `chapterCard`) reprise aux jetons du thème (`AppColors.surfaceHigh`,
  `AppRadii.cardBorder`, typographie tabulaire) cette session — c'était
  le dernier élément notable en ancien langage visuel de ce composant
  précis.
- Reste en dette de style (non traité, cf. Bugs connus) : ~20 fichiers
  d'overlays/indicateurs (volume, luminosité, vitesse, capture d'écran,
  plein écran audio, sélecteur de sous-titres) en couleurs/rayons bruts
  (`Colors.black.withValues(...)`, `BorderRadius.circular(16)`) plutôt
  qu'en jetons.

### Module Arr — Sonarr/Radarr (`lib/arr/`)

**Contrairement à `CLAUDE.md` qui le décrit comme "à venir", ce module
est déjà largement livré et testé** (16 fichiers de test, aucun
TODO/FIXME). Structure : `models/`, `services/` (`ArrApiClient` abstrait
+ `RadarrApiClient`/`SonarrApiClient`, `ArrCredentialsStore` en
`flutter_secure_storage`, client + coffre qBittorrent séparés),
`providers/`, `screens/` (accueil à onglets, bibliothèque, file
d'attente, calendrier, recherche interactive, réglages), `screens/widgets/`.

Fonctionnalités livrées : file d'attente (retrait avec option
"retirer du client"/"blocklist" séparées, import forcé), calendrier
(vue semaine/mois), recherche interactive de releases (tri, tooltip de
rejet, sélection saison/épisode, grab), fiche détail (surveiller,
recherche auto/interactive, édition profil qualité/dossier
racine/monitored, suppression), bibliothèque (grille paginée,
tri/filtre), réglages (URL + clé API par service, test de connexion,
config qBittorrent). Lien avec Jellyfin : recherche par titre normalisé
+ année (pas d'ID externe exposé par l'API générée), best-effort,
alimente aussi la redirection Jellyfin de la rangée "Vous l'aviez mis
de côté" côté recommandations.

Manque : pas d'écran de consultation de la blocklist après coup
(l'action existe seulement au retrait de file), pas de vue dédiée
qBittorrent (torrents/progression) au-delà de la configuration.
`CLAUDE.md` § Reste à faire est obsolète sur ce point.

### Module Seerr — Overseerr/Jellyseerr (`lib/seerr/`, `lib/screens/seerr/`)

**Non mentionné dans le périmètre de `CLAUDE.md`** (qui borne à
Jellyfin + Arr), mais activement entretenu au même rythme que le reste
de l'app (plusieurs refactors visuels récents) et sert un besoin
adjacent réel : demander l'ajout d'un film/série absent de la
bibliothèque, suivre le statut, gérer les demandes côté admin. Deux
entrées dans la barre latérale ("Découverte", "Demandes"), visibles
seulement si un service Seerr est configuré.

Architecture : client Chopper/Swagger généré (même pattern que le
client Jellyfin), un seul service actif par compte (pas de
multi-instance comme Arr). **Aucun test** — seul module fonctionnel
majeur sans couverture.

**À trancher** : soit `CLAUDE.md` doit inclure Seerr explicitement dans
le périmètre, soit son avenir (maintien/gel/retrait) doit être décidé.
Indépendamment de cette décision, voir Bugs connus pour une faille de
sécurité concrète sur ce module.

### Persistance locale (Drift, `lib/models/syncing/`)

`AppDatabase`, schéma v3, 5 tables : `DatabaseItems` (cache
Jellyfin synchronisé/téléchargé), `PlaybackQueue` (outbox des rapports
de lecture), `PaletteCache` (couleur dominante de jaquette),
`Settings` (clé/valeur scopée), `RecommendationCacheEntries` (dernier
calcul de recommandations, scope explicite par `userId` en colonne
pour rendre une fuite entre profils impossible et testable).
Migrations v1→v2→v3 testées (`app_database_migration_test.dart`),
schémas exportés dans `drift_schemas/`.

**Rapports de lecture** : `PlaybackReportQueueWorker`
(`@Riverpod(keepAlive: true)`) draine `PlaybackQueue` en continu
(timer 30 s + retour de connectivité + rattrapage au démarrage).
Backoff exponentiel par entrée (base 5 s, doublé par tentative,
plafonné à 5 min, testé). Avant envoi, `PlaybackConflictResolver`
réconcilie avec l'état serveur (drop si le serveur est déjà plus
avancé ou l'item déjà marqué vu) — remplace un ancien envoi
fire-and-forget qui perdait silencieusement les rapports en cas de
coupure réseau.

**Secrets** : deux coffres séparés (`SecureCredentialsStore` pour
Jellyfin, `ArrCredentialsStore` pour Radarr/Sonarr + qBittorrent),
même schéma de clé composite, tous deux sur `flutter_secure_storage`.
Seerr fait exception — voir Bugs connus.

### Synchronisation / téléchargement offline (`lib/providers/sync_provider.dart` et alentours)

Système hérité d'amont, générique multi-médias (**y compris musique**,
hors périmètre déclaré par `CLAUDE.md`), fonctionnel sur la cible
desktop de ce fork (chemin de sauvegarde explicitement branché sur
Windows/Linux/macOS via `clientSettingsProvider.syncPath`, pas un
simple repli mobile). `SyncNotifier` (1333 lignes) pilote
ajout/suppression/rafraîchissement ; le téléchargement effectif passe
par le package `background_downloader` (`BackgroundDownloader`,
`keepAlive`) ; état persisté dans les colonnes `DatabaseItems.path`/
`videoFileName`/`fileSize`/`syncing`. Écrans dédiés complets sous
`lib/screens/syncing/`. **Aucun test.** Le point exact qui fait lire un
fichier local plutôt que le flux réseau au moment de la lecture n'a pas
été retracé dans cette passe.

### Thème / design system (`lib/theme/app_theme.dart`)

Un seul thème sombre. Jetons : `AppColors` (`background` #0A0A0A,
`surface` #141414, `surfaceHigh` #1C1C1C — attention, `ColorScheme.dark`
mappe `colorScheme.surface` sur `AppColors.background`, pas sur
`AppColors.surface`, piège déjà rencontré plusieurs fois), `AppSpacing`
(xxs 4 → md 16), `AppRadii` (control 4, card 8, sheet 12),
`AppTypography` (échelle display/section/card/body/meta, rapport 1:3
entre titre d'écran et métadonnées — c'est le principal levier de
caractère du projet, cf. `CLAUDE.md`), `AppDensity` (bureau vs salon,
facteur 1.35 sur cibles tactiles/espacements en mode salon).
`AppTokens` (extension de thème) porte la teinte de bandeau courante et
son texte secondaire dérivé.

## Décisions d'architecture transversales

- **Riverpod pour tout l'état, `lib/providers/` protégé** : aucun appel
  API direct depuis un widget. Effet observé dans les modules récents
  (recommandations, Arr) : chaque source de données lente est un
  `FutureProvider.autoDispose` séparé, combiné dans un provider de plus
  haut niveau — permet à Riverpod de dédupliquer un aller-retour déjà
  en cache entre deux consommateurs (ex. `recommendationResultProvider`
  partagé entre "Pour vous" et le registre de déduplication) sans
  aucune coordination manuelle.
- **`ref.keepAlive()` après succès, jamais avant** : pattern récurrent
  (recommandations, rapports de lecture) pour qu'un calcul coûteux ne
  soit fait qu'une fois par session, sans pour autant garder en
  mémoire un état d'échec qui empêcherait un vrai retry au prochain
  accès.
- **Secrets dans `flutter_secure_storage`, jamais `SharedPreferences`,
  clé composite systématique** (`serverId:userId`, `arr:<service>`) —
  appliqué et testé pour Jellyfin et Arr/qBittorrent, migration
  ponctuelle depuis l'ancien stockage en clair pour Jellyfin. Non
  appliqué à Seerr (cf. Bugs connus).
- **Toute indirection réseau différée passe par une file Drift, jamais
  fire-and-forget** : `PlaybackQueue` pour les rapports de lecture,
  `background_downloader` + `DatabaseItems` pour les téléchargements.
  Motivé par des pertes silencieuses observées avec l'ancien envoi
  direct.
- **Diversité calculée sur le même trait que la justification affichée**
  (recommandations) plutôt que deux calculs indépendants qui
  pourraient diverger — décision explicite documentée dans
  `recommendation_scorer.dart`.
- **Grilles à hauteur de cellule explicite (`mainAxisExtent`), jamais
  `childAspectRatio`, dès qu'une cellule porte un libellé sous
  l'image** : `childAspectRatio` reconverti en pixels par le delegate
  peut tomber en-deçà de la hauteur réelle du libellé de quelques
  dixièmes de pixel → bande de débordement visible sur toute la
  grille. Établi dans `season_episode_section.dart`/
  `media_info_section.dart`, généralisé cette session à
  `episode_details_list.dart`/`continue_watching_section.dart`. Les
  grilles de jaquettes pures (sans libellé, ou construites en
  `Expanded`/`Flexible` sous un `AspectRatio` — `PosterWidget`,
  `EpisodePoster`) n'ont pas ce risque et gardent `childAspectRatio`.

## Bugs connus non corrigés

1. **Sécurité — identifiants Seerr stockés en clair.**
   `SeerrCredentialsModel` (apiKey/sessionCookie) est un champ
   d'`AccountModel`, persisté par `SharedHelper.saveAccounts` dans
   `SharedPreferences`. `_stripCredentials`
   (`lib/providers/shared_provider.dart:252-267`) blanchit les
   identifiants Jellyfin avant écriture mais pas `seerrCredentials` —
   la clé API/le cookie de session Seerr partent en clair sur disque,
   alors que le même traitement a déjà été fait pour Jellyfin et Arr.
   Aucun test ne couvre ce chemin. Correctif : même migration que
   `1fd66db2`/`97fe7224` (Jellyfin), adaptée à Seerr.
2. **Commentaires de code périmés décrivant du travail déjà livré comme
   "à faire".** `PlaybackQueue` (`lib/models/syncing/playback_queue_table.dart:9-15`,
   "this table lets a *future* retry worker…") et
   `RecommendationCacheEntries` (`recommendation_cache_table.dart:41-43`,
   "reste à faire") — les deux fonctionnalités décrites sont
   implémentées. À corriger à l'occasion, risque de désorienter une
   relecture future.
3. **Dette de style dans le lecteur vidéo** (voir section Lecteur) —
   ~20 fichiers d'overlays/indicateurs en couleurs et rayons bruts
   plutôt qu'en jetons du thème. Identifié et délibérément non traité
   cette session (hors scope de la demande initiale), chantier à part
   entière si souhaité.
4. **Zéro test sur ~1650 lignes de code (Seerr + synchronisation
   offline).** Pas un bug en soi, mais une surface sans filet pour
   toute modification future de ces deux zones.
5. **`CLAUDE.md` § Reste à faire obsolète** sur ses trois points
   (module Arr livré, UI très largement réécrite, renommage/logo
   faits) — à mettre à jour séparément, ce document ne s'y substitue
   pas.

## Mesures de performance actuelles

- **Requête bibliothèque "non vus" (recommandations)** : goulot
  d'étranglement identifié à 45 s en requête unique. Calibrage
  mesuré : pagination en pages de 200 + concurrence 4 → 29 s ;
  concurrence 6 → 28,4 s mais page la plus lente en hausse de 50 %
  (19,6 s contre 13,1 s, 69 % du temps total — signe de saturation
  serveur, pas de gain réel). Réglage retenu : **pages de 200,
  concurrence 4** (`unwatchedFetchPageSize`/`unwatchedFetchConcurrency`,
  `recommendation_providers.dart:110-112`) — c'est le plancher réseau
  mesuré (~28-29 s), avec des pages individuellement assez rapides
  pour permettre un premier affichage progressif (première page
  publiée dès qu'elle répond, bien avant la fin du calcul complet) au
  lieu d'un écran vide pendant toute la durée de la requête.
- **Calcul de notation lui-même** (hors réseau) : de l'ordre de la
  dizaine de millisecondes sur un profil/bibliothèque typiques (mesuré
  informellement pendant le calibrage, pas un benchmark automatisé
  committé) — négligeable face au coût réseau ci-dessus, ce qui a
  motivé la duplication du calcul plutôt qu'un couplage entre
  `recommendationResultProvider` et `homeCatalogResultProvider`.
- **Seuil de recalcul des recommandations** : 24 h
  (`defaultRecommendationRecomputeThreshold`) — un retour à l'accueil
  dans cette fenêtre ne relance jamais la chaîne complète, affiche le
  cache Drift directement.
- Aucun autre benchmark automatisé (démarrage à froid, temps de
  première frame, mémoire) n'existe dans le dépôt à ce jour.

## Reste à faire

- **Commiter le travail en cours** (cf. État du dépôt) — le module
  recommandations complet, le calendrier Arr, et les quatre correctifs
  de cette session sont fonctionnels et testés mais pas encore
  committés.
- **Corriger la fuite de sécurité Seerr** (Bugs connus, point 1) —
  priorité avant tout usage réel du module avec un compte Seerr
  personnel.
- **Trancher le périmètre de Seerr** vis-à-vis de `CLAUDE.md` (inclure
  explicitement, ou geler/retirer).
- **Mettre `CLAUDE.md` § Reste à faire à jour** (module Arr,
  réécriture UI, renommage/logo).
- **Reprendre le style du lecteur vidéo** (jetons de thème) sur les
  ~20 fichiers identifiés — overlays/indicateurs, plein écran audio,
  sélecteur de sous-titres.
- **Ajouter des tests** sur le module Seerr et sur
  `sync_provider.dart`/`background_download_provider.dart` avant toute
  modification non triviale de ces zones.
- **Écran de consultation de la blocklist Arr** (actuellement, retirer
  un item de file l'y envoie mais rien ne permet de la relire/gérer
  ensuite) ; **vue qBittorrent dédiée** (liste des torrents,
  progression — le client et les identifiants existent déjà,
  seulement la vue manque).
- **Vérification manuelle du module recommandations** (déjà notée dans
  le plan d'origine, jamais cochée) : lancer l'app, confirmer qu'aucun
  titre n'apparaît deux fois sur la page d'accueil, que les rangées
  par graine sont bien titrées depuis une œuvre vue, navigation
  clavier sur les nouvelles rangées.
- **Retracer le chemin lecture-locale-vs-réseau** du système de
  synchronisation offline avant d'y toucher (non localisé dans cette
  passe).
