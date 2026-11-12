# État des lieux — Kinos

Dernière mise à jour : 2026-11-12 (v0.12.4, `f0fe54be`). Les sections
détaillées plus bas datent pour l'essentiel du 2026-10-08 ; ce qui a changé
depuis est résumé dans « Travail depuis le 8 octobre ». Ce document est un instantané factuel
pour reprendre le travail sans repartir de zéro. Il ne répète pas les
règles et contraintes de `CLAUDE.md` (zones de fork, contraintes mpv/HDR,
direction UI, conventions, feuille de route déclarée) — seulement l'état
réel du code : ce qui est implémenté, comment, et ce qui reste à faire.

## Concept de l'app

Kinos est un client Jellyfin desktop, fork de Fladder (GPL-3.0-only).
Développé et utilisé d'abord sous Linux (CachyOS/Hyprland, AMD RDNA2) ;
les versions publiées depuis v0.12.0 visent Windows et macOS. Périmètre : **films et séries
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

Deux intégrations de compte externes s'y ajoutent : **AniList** (suivi
de progression des séries) et **import Letterboxd** (profil de goût).

Direction produit : UI desktop sans concession (pas de navigation basse,
survol partout, clic droit, raccourcis visibles, focus clavier directionnel
sur tout élément interactif dès le premier écran), austère dans les
éléments mais typographiquement affirmée. Une UI "mode salon" à double
densité est prévue, portée par le même code (cf. `AppDensity`).

## Vue d'ensemble technique

- ~1850 commits depuis le fork d'amont. Stack : Flutter 3.47.0 (fvm),
  Dart 3.13.0, Riverpod 2.6.1, Drift 2.28.1, auto_route 10.1.2,
  dart_mappable 4.6.0, chopper 8.3.0 (clients API générés), media_kit
  1.2.2 (via mpv), flutter_secure_storage 10.3.1, Freezed 3.1.0.
- **640 tests** passent (74 fichiers de tests, en forte hausse depuis le
  dernier instantané — 412 au 23 septembre, +99 pour Seerr, +quelques
  dizaines pour la migration/résilience des identifiants, puis +30 pour
  la découverte Seerr et sa migration Drift). Répartition
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
  *Au 2026-11-12 : 156 fichiers de test (dont `test/anilist/` et
  `test/letterboxd/`, 26 fichiers à eux deux) ; le nombre de tests n'a pas
  été recompté.*
- CI : `.github/workflows/checks.yaml` (lint/format), `build.yml`,
  `prepare-release.yml`, `validate-fastlane.yml` hérités d'amont
  (déclenchés sur PR vers `develop`). La chaîne propre à Kinos est
  `desktop-test.yml` : builds Windows/macOS/Linux et tests bornés, puis,
  sur tag `v*`, release GitHub avec `kinos-windows-x64-portable.zip`,
  `kinos-macos-universal.zip` et `SHA256SUMS.txt`. Le tarball et
  l'AppImage Linux sont construits et validés mais pas publiés.
- Le lot découverte Seerr, non committé au 2026-10-08, a été intégré
  depuis (`1c0d0942` / `35216f93`). `AGENTS.md` est une copie de
  `CLAUDE.md`.

## Travail depuis le 8 octobre (→ v0.12.4, 8 novembre)

- `1c0d0942` (30 oct.) — refonte desktop, mouvement et stabilisation
  intégrés.
- `35216f93` (3 nov.) — consolidation des intégrations Kinos et premiers
  builds de test desktop.
- 4–5 nov. — **AniList** : correspondance d'identifiants (requête par
  identifiant unique), plages manuelles d'épisodes enregistrées hors
  ligne, liens conservés hors ligne, liens de série respectés à la
  synchronisation, épisodes marqués à la main synchronisés, réutilisation
  d'une correspondance périmée plutôt qu'une nouvelle demande.
- **Letterboxd** : import livré (`lib/letterboxd/`).
- 4–8 nov. — CI de release desktop, licences des polices embarquées,
  série de correctifs macOS (entitlements, signature ad hoc, stockage des
  identifiants — cf. Secrets).
- `dfde798e` (6 nov.) — connexion en deux étapes (serveur puis compte,
  états de découverte explicites), Quick Connect en secondaire, actions
  de profil sous la grille, focus clavier et tests de widgets.
- Releases : v0.12.0 (6 nov.), puis v0.12.1 → v0.12.4 (8 nov.). Attention : ces quatre
  versions portent par erreur les tags git `v1.12.1` → `v1.12.4`, et
  `pubspec.yaml` est en `1.12.4+1`.
- `f0fe54be` (8 nov., v0.12.4) — téléchargement des sous-titres distants
  amélioré, options du lecteur enrichies
  (`video_player_options_sheet.dart`), ajustements de `lib_mpv.dart`.

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

Le bandeau d’accueil prend désormais jusqu’à huit films aléatoires dans toute
la bibliothèque via un provider dédié (`hero_items_provider.dart`), vus ou
non vus. Une seule requête Jellyfin `SortBy=Random` par session/profil ; les
retours à l’accueil et rafraîchissements des informations du profil gardent
la sélection. La rangée « Ajouts récents » conserve sa source actuelle.

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
  Linux, défaut sur tous les desktops) et `lib_mdk.dart` (hérité, encore
  sélectionnable sous Windows/macOS via `PlayerOptions.available`). `media_control_wrapper.dart` fait le pont commun ;
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

**Décision du 29 octobre 2026** : la vue qBittorrent dédiée est abandonnée,
hors périmètre. Les clients et identifiants existants sont conservés.

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

**Lot "découverte hors catalogue" : implémenté, tests automatisés passés.**
Module isolé sous `lib/recommendations/seerr/`, deux rangées « Films à découvrir »
et « Séries à découvrir » après les graines et avant l'inventaire, jusqu’à
15 titres chacune selon les candidats éligibles. Défilement horizontal au
clavier et par boutons fléchés à droite du titre ; sans barre de défilement
ni défilement horizontal à la souris ; quotas séparés. Jusqu'à quinze films
et quinze séries de l'historique, classés par signal positif × décroissance temporelle (éditions dédoublonnées),
une page de similaires et une page de recommandations par œuvre. Pot enrichi
borné à 60 fiches, équilibré entre graines/routes, soit au plus 120 requêtes
Seerr hors nouvelle tentative HTTP. Deux appels simultanés, deux départs par
seconde, timeout de 15 s, respect de `Retry-After`, une seule nouvelle tentative
sur 429 puis délai persistant avant prochain calcul (au moins cinq minutes).

Adaptation des genres (alias français/anglais), quatre premiers acteurs,
vrais réalisateurs, mots-clés, studios et décennie vers le moteur existant ;
score positif requis, diversité du scorer conservée. Calcul du profil et du
classement dans un isolate. Les fiches sont décodées dans un DTO propre au
lot, qui conserve les mots-clés film absents du modèle Seerr historique.
Le client HTTP est dédié, utilise les identifiants existants uniquement en
en-têtes et se ferme à la destruction du provider. Aucun secret en cache.

Exclusions : présence d'un `mediaInfo` non vide (choix conservateur, y compris
anciens refus/statuts inconnus/4K), bibliothèque Jellyfin complète par ID,
Radarr par TMDB et Sonarr par TVDB/IMDb. Chaque calcul prend son propre
instantané des bibliothèques en arrière-plan ; aucune attente ajoutée aux
autres rangées. Les statuts Seerr des candidats retenus sont contrôlés pendant
le calcul courant, jamais autorisés depuis le seul cache. Une demande locale
réussie retire immédiatement le titre. Le registre d'accueil reçoit les IDs
externes typés sans dépendre du calcul réseau de la rangée.

Synchronisation Jellyfin initiale : pages de métadonnées de 50 titres,
séquentielles, délai de 30 s par page ; un instantané incomplet reste rejeté.
Les traits sont ensuite conservés dans le cache Drift existant, sans nouvelle
table ni historique utilisateur. Chaque calcul suivant lit un inventaire
léger de 500 IDs par page avec les données de lecture actuelles, récupère les
métadonnées modifiées via `minDateLastSaved` (recouvrement de cinq minutes),
et cible les IDs manquants. Suppressions et identifiants retirés sont reflétés
immédiatement dans l’instantané. Cache expiré ou invalide : nouvelle
synchronisation complète en arrière-plan. Tests du cache et des quotas passés.
La mise à jour des informations du profil et le retour du focus pendant un
calcul ne le relancent plus. Les traces de debug indiquent le numéro du calcul,
sa progression et distinguent annulation et erreur sans journaliser de secrets.
Deux erreurs de rafraîchissement de l'accueil ont aussi été reproduites et
corrigées : remise à zéro de l'aperçu pendant l'initialisation Riverpod et
notification du carrousel pendant la construction de son parent.

Cache Drift dédié de sept jours, réglable à 1/3/7/14/30 jours dans les réglages
des rangées : listes, fiches et métadonnées Jellyfin versionnées, réponses vides incluses, scope
serveur Jellyfin/utilisateur/instance Seerr/langue. Activation migrée une seule
fois ; une suppression volontaire n'est pas annulée aux lancements suivants.
La rangée démarre après la première frame, reste absente pendant chargement,
revérification ou erreur et en mode hors ligne. Consulter une fiche Seerr ou
revenir au focus conserve le résultat ; une demande réussie retire uniquement
le titre concerné. Carte « À demander » avec
navigation exclusivement vers Seerr, focus directionnel, menu clic droit et
Maj+F10, jetons du thème, libellés français/anglais (repli anglais ailleurs).

**Validation réelle encore à faire** : pertinence des candidats et fraîcheur
des exclusions contre les instances de l'utilisateur, inspection avec de
vraies jaquettes et mesure des temps de frame dans l'application. Les tests
vérifient l'absence d'attente du premier rendu et les débordements bureau/salon,
pas une absence absolue de contention réseau/CPU. La garantie d'exclusion reste
limitée par les identifiants et la fraîcheur des données exposées côté serveurs.

### AniList (`lib/anilist/`)

Livré début novembre. Compte AniList (jeton via `flutter_secure_storage`,
`anilist_account.dart`), client API, correspondance Jellyfin → AniList
(`mapping.dart`, dialogue de choix parmi les candidats résolus), plages
d'épisodes manuelles (`episode_store.dart`, table Drift `Settings`
scopée), progression remontée depuis `playback_report_queue_provider.dart`
(jamais en appel direct). Liens et plages restent utilisables hors ligne.
Points d'entrée UI : fiches série/saison/film, réglages du profil.

### Import Letterboxd (`lib/letterboxd/`)

Livré. Analyse de l'export Letterboxd, rapprochement avec la bibliothèque,
instantané par profil (`letterboxdSnapshotProvider`), dialogue d'import
depuis les réglages du profil. Conformément à la feuille de route, il
alimente le profil de goût des recommandations, jamais les candidats.

### Persistance locale (Drift, `lib/models/syncing/`)

`AppDatabase`, schéma v4, 6 tables : `DatabaseItems` (cache Jellyfin
synchronisé/téléchargé), `PlaybackQueue` (outbox des rapports de
lecture), `PaletteCache` (couleur dominante de jaquette), `Settings`
(clé/valeur scopée), `RecommendationCacheEntries` (dernier calcul de
recommandations, scope explicite par `userId`), `DiscoveryCacheEntries`
(listes/fiches de découverte Seerr, scope composite explicite). Migrations
v1→v2→v3 et v1/v2/v3→v4 testées avec conservation des données ; schémas
exportés dans `drift_schemas/`.

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

**Exception macOS (depuis `084af800`, v0.12.3)** : sans profil Developer ID,
les builds ad hoc n'ont pas accès au Trousseau.
`lib/services/platform_secure_storage.dart` remplace alors le backend de
`flutter_secure_storage` par un fichier `credentials.json` dans le dossier
Application Support, aux permissions restreintes mais non chiffré. Tous les
coffres (Jellyfin, Arr, Seerr, AniList) en dépendent sur macOS. Raccourci
documenté dans le code, à remplacer par le Trousseau dès qu'un Developer ID
existe.

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

## Bugs connus et suivi

1. **Conversion Seerr et résultats API — corrigés le 29 octobre 2026.**
   Les réponses 2xx malformées ou vides pour un type concret ne provoquent
   plus un second `TypeError`. L’intercepteur préserve l’erreur malgré le
   traitement interne de Chopper ; les deux accès `.apiResult` refusent un
   faux succès. Les réponses sans contenu 204/205 et le JSON `null` pour un
   type nullable ou dynamique sont conservés. Le résultat API synchrone lit
   explicitement `this.body` pour éviter l’annotation Chopper homonyme.
   Aucun contenu de réponse invalide n’est imprimé par le convertisseur.
2. **Seerr : erreurs HTTP encore brutes, attente réseau bornée.**
   L’absence d’`errorConverter` laisse encore les erreurs HTTP non-2xx sous
   forme de chaîne JSON ou HTML. Leur présentation reste à améliorer.
   Depuis le 29 octobre 2026, l’intercepteur borne à 30 secondes la requête
   complète, y compris la réception du corps, et déclenche l’annulation HTTP.
   Une annulation déjà fournie est conservée. Aucune nouvelle tentative
   automatique n’est ajoutée : après un délai dépassé sur une écriture, le
   serveur peut avoir reçu la demande même sans réponse côté client.
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
7. **Identifiants macOS en fichier local non chiffré** (cf. Secrets) —
   choix assumé pour les builds ad hoc, à lever avec un Developer ID.

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
Feuille de route. Priorités validées le 29 octobre 2026 : stabilisation
de Kinos normal (y compris validation Seerr) → AniList → import
Letterboxd → mode salon → préparation de la version distribuable propre,
en toute fin. **AniList et Letterboxd sont livrés** (novembre 2026). Le Lab
Plezy/Plex reste de côté.

Ouverts côté code, dans un ordre de priorité suggéré :

- **Lot Seerr "découverte hors catalogue"** — committé et publié ; reste à
  valider contre les vrais serveurs et à mesurer le rendu. Ce lot conserve son délai propre ; le client Seerr historique
  est désormais borné à 30 secondes. La présentation des erreurs HTTP reste
  à améliorer.
- **Fixtures Seerr réelles** à capturer (`discover/trending`,
  `movie/<id>`, `tv/<id>`, `requests`) pour remplacer les 3 fixtures
  synthétiques identifiées dans `test/fixtures/seerr/README.md`, avec
  nettoyage des champs personnels avant capture.
- **Présentation des erreurs HTTP Seerr** — simplifier les messages JSON/HTML
  non-2xx. Le défaut de conversion et le délai maximal du client sont corrigés.
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
- **Déconnexion Discord au play** — idée notée, mis de côté, aucun code
  (vérifier `pactl list sinks` avant/pendant lecture avec Discord en
  vocal).
- **Trousseau macOS** (Bugs connus 7) — dès qu'un Developer ID existe.
- **9 messages non traduits** et **relecture du `NOTICE`** avant
  publication (déjà notés dans `CLAUDE.md` § En attente).
