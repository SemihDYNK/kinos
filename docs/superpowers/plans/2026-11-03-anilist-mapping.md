# AniList Mapping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Proposer et confirmer des liens AniList fiables depuis les fiches Jellyfin, sans synchroniser le suivi.

**Architecture:** Nouveau module `lib/anilist/`, résolution déterministe par IDs, catalogue public partagé et chargé à la demande, choix manuels dans la table Drift Settings existante. Un panneau glass est le seul déclencheur des recherches ; le lecteur et l'accueil restent indépendants.

**Tech Stack:** Flutter 3.47, Dart 3.13, Riverpod 2.6, http, flutter_cache_manager, Drift et url_launcher déjà installés.

**Spec:** `docs/superpowers/specs/2026-11-03-anilist-mapping-design.md`, validée par l'utilisateur le 3 novembre 2026.

## État de l’exécution au 3 novembre 2026

Le module et les trois entrées de menu sont implémentés, sans modification de la
couche protégée existante. Les points de relecture (DTO de saison brut, sélection
invisible après recherche, annulation réelle du timeout HTTP) ont été corrigés
avec tests. Les détails ci-dessous restent le plan original, pas une attestation
de recette réelle.

Validation : suite globale 887 tests réussis ; 40 tests AniList ciblés après les derniers garde-fous ;
analyse ciblée sans diagnostic ; compilation Linux profile réussie. La recette
réelle avec AniList reste à faire : HTTP 403 sur l’API publique depuis cet
environnement. Traductions anglais/français ajoutées, repli anglais ailleurs.
Aucun commit ni push de ce lot ; les changements de stabilisation antérieurs
restent intacts. Aucun envoi de progression, de note ou d’activité n’est activé.

## Global Constraints

- Films et séries uniquement ; requêtes AniList limitées à `type: ANIME`.
- Pas d'OAuth, mutation AniList, écriture Jellyfin ou synchronisation de progression/notes.
- Aucun suivi par épisode dans ce lot ; les offsets des sources sont toutefois conservés et affichés (précision JoJo validée pendant l’implémentation).
- Aucun changement prévu dans `lib/providers/`, `lib/models/`, `lib/wrappers/` ou le lecteur.
- Aucun ajout de dépendance ni nouvelle table/migration Drift.
- Catalogue chargé à la demande, indexé hors UI, fraîcheur 24 h, dernier fichier valide conservé.
- Une requête AniList à la fois, intervalle minimal 2 s, timeout 15 s, respect de Retry-After.
- Choix manuels isolés par serveur/profil/objet, invalidés pour confirmation si leurs IDs sources changent.
- Matériau glass, jetons de thème, navigation directionnelle et focus visible existants.
- Ne pas incorporer les changements de stabilité non commités dans les commits AniList.

## Review Focus

- Un même numéro TMDB peut identifier un film et une série différents : namespaces séparés (tâche 1).
- Les numéros de saisons TMDB/TVDB peuvent diverger ; une série AniList unique ne prouve pas l'identité d'une saison Jellyfin (tâche 1).
- Une fermeture de panneau ou un changement de profil pendant une requête ne doit jamais sauvegarder un choix pour l'ancien profil (tâches 3 et 4).
- Un catalogue invalide ou une erreur GraphQL HTTP 200 ne doit pas effacer les liens/cache valides ni être présenté comme une absence de résultat (tâches 2 et 3).
- Un choix manuel précédemment valide devient à confirmer si les IDs ou le contexte de saison changent (tâche 3).

## Fichiers et interfaces

- `lib/anilist/mapping.dart` : types simples, normalisation, index et résolution pure.
  `AnilistTarget` : itemId, kind (movie/series/season), IDs de l'objet, IDs parent éventuels, numéro de saison nullable et référentiel nullable.
  `AnilistMatch` : statut exact/needsConfirmation/notFound/unavailable, candidats dédupliqués, provenance et raison.
  `AnilistCatalogIndex.fromJson(Object?)`, `resolveAnilistTarget(AnilistTarget, AnilistCatalogIndex)` ; aucune dépendance Flutter/API dans ce résolveur.
- `lib/anilist/jellyfin_target.dart` : `anilistTargetFromItem(ItemBaseModel, {SeriesModel? parent})`, sans modifier les modèles existants. Séparer les IDs propres d'une saison et ceux de sa série.
- `lib/anilist/anilist_client.dart` : `AnilistClient({http.Client? client})`, `media({int? id, int? malId})`, `search(String title)`, `close()`. Résultats : id, idMal, titres, format, année ; URL de consultation construite depuis l'ID validé.
- `lib/anilist/anilist_catalog.dart` : `AnilistCatalog.load() -> Future<AnilistCatalogIndex>` ; une seule tâche en cours, cache injecté et parser isolé. Validation avant remplacement du cache.
- `lib/anilist/anilist_store.dart` : `AnilistStore(AppDatabase, String scope)` ; `read(AnilistTarget)`, `save(AnilistTarget, int anilistId)`, `remove(AnilistTarget)`. Empreinte JSON canonique des IDs et du contexte, pas de secret.
- `lib/anilist/anilist_providers.dart` : provider catalogue partagé paresseux ; `anilistMappingProvider.family` autoDispose par cible, controller Riverpod pour `resolve()`, `search(String)`, `confirm(int)`, `remove()`. Résultat distinct des erreurs réseau et du chargement.
- `lib/anilist/anilist_mapping_dialog.dart` : `showAnilistMappingDialog(BuildContext, ItemBaseModel) -> Future<void>`. Le panneau lit les providers ; aucun accès API depuis un widget.
- Intégration : `movie_detail_screen.dart`, `series_detail_screen.dart`, `season_detail_screen.dart`, dans `lib/screens/details_screens/`.
- Textes : `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`, sorties `lib/l10n/generated/` générées avec `fvm flutter gen-l10n`.
- Attribution : ajout ciblé au `NOTICE`, sans redistribuer le catalogue public.

## Tâche 1 — Identités et ambiguïtés déterministes

**Files:** créer `mapping.dart`, `jellyfin_target.dart`, `test/anilist/mapping_test.dart`, `test/anilist/jellyfin_target_test.dart`, petite fixture `test/anilist/fixtures/catalog.json`.

**Interfaces:** consomme les modèles Jellyfin existants ; produit les cibles normalisées, l'index et les candidats sans IO.

- [ ] Écrire les tests : casse AniList/MAL/AniDB/TMDB/TVDB/IMDb, ID nul/négatif/décimal/malformé, namespaces TMDB film/série et doublons vers le même AniList.
- [ ] Ajouter les cas : IDs concordants, ensembles de candidats disjoints donc conflit, fournisseur inconnu sans correspondance, saison nulle distincte de 0, saison parent non propagée, plusieurs cours et saison sans référentiel connu.
- [ ] Utiliser une fixture réduite contenant un film, Death Note, Naruto Shippuden sans saison et deux fiches partageant un ID de série. Aucun téléchargement en test.
- [ ] Exécuter `fvm flutter test test/anilist/mapping_test.dart test/anilist/jellyfin_target_test.dart` et constater l'échec avant implémentation.
- [ ] Implémenter les interfaces ci-dessus. Les contraintes de fournisseurs se croisent ; les candidats ambigus ne sont jamais réduits par choix du premier résultat. Garder la provenance de chaque correspondance.
- [ ] Relancer les tests ; vérifier que la série Naruto peut avoir un lien d'œuvre sans que ses saisons acquièrent automatiquement un lien exact.
- [ ] Relire puis commiter seulement les fichiers de cette tâche.

## Tâche 2 — Catalogue et API publique résilients

**Files:** créer `anilist_client.dart`, `anilist_catalog.dart`, `test/anilist/client_test.dart`, `test/anilist/catalog_test.dart`.

**Interfaces:** consomme les types de la tâche 1 ; produit les fiches AniList vérifiées et un index public prêt à résoudre.

- [ ] Écrire les tests http.MockClient : variables GraphQL, ANIME obligatoire, id et idMal, recherche sur action explicite, succès, 404, erreur HTTP, HTTP 200 avec errors, JSON invalide, 429 Retry-After, timeout et fermeture pendant une requête/attente.
- [ ] Écrire les tests du cache injecté : un téléchargement partagé, cache frais sans HTTP, cache périmé rafraîchi, ancien index valide conservé si le nouveau JSON est invalide, aucune sauvegarde partielle.
- [ ] Lancer les deux suites et vérifier qu'elles échouent avant l'implémentation.
- [ ] Implémenter le client avec une file annulable, 2 s entre départs et timeout 15 s ; exposer retryAt sur 429 sans attente infinie ni relance automatique en boucle. Une réponse GraphQL invalide reste une erreur.
- [ ] Implémenter le catalogue depuis `https://raw.githubusercontent.com/Fribb/anime-lists/master/anime-list-full.json` : cache 24 h, indexation dans Isolate.run, téléchargement/validation avant remplacement. Ne pas cacher les erreurs derrière un index vide.
- [ ] Refuser une réponse catalogue au-delà de 32 MiB et un schéma racine différent d'une liste ; conserver le dernier index valide. Ajouter le test de dépassement.
- [ ] Exécuter `fvm flutter test test/anilist/client_test.dart test/anilist/catalog_test.dart` ; aucune requête réelle dans ces tests.
- [ ] Relire puis commiter seulement les fichiers de cette tâche.

## Tâche 3 — Choix locaux et état Riverpod isolés

**Files:** créer `anilist_store.dart`, `anilist_providers.dart`, `test/anilist/store_test.dart`, `test/anilist/providers_test.dart`.

**Interfaces:** consomme cibles/index/client ; produit l'état du panneau et les opérations explicites de confirmation/retrait.

- [ ] Tester avec Drift en mémoire : lecture après réouverture, aucun mélange entre profils/serveurs/saisons, retrait d'un choix sans supprimer les autres, empreinte inchangée ou invalidée après changement d'IDs.
- [ ] Tester les providers remplacés par des fakes : aucun IO sans ouverture du panneau ; priorité d'un choix manuel valide ; ID AniList/MAL vérifié ; erreur réseau distincte de notFound ; parent série chargé seulement pour une saison qui le nécessite.
- [ ] Ajouter le cas critique : changer de profil pendant resolve/search/confirm annule ou ignore le résultat et interdit l'écriture dans l'ancien scope. Tester aussi la fermeture du panneau pendant une requête.
- [ ] Lancer `fvm flutter test test/anilist/store_test.dart test/anilist/providers_test.dart` et constater l'échec.
- [ ] Implémenter les choix dans Settings via les méthodes existantes d'AppDatabase. Scope versionné serveur/profil, clé d'item, payload ID/provenance/empreinte. Si serverId manque, repli URL canonique sans userInfo/query/fragment ; aucune URL avec secret stockée ou loguée.
- [ ] Implémenter les providers : lecture userProvider et appDatabaseProvider existants, client lié au panneau avec close sur dispose, catalogue public partagé. Une saison peut lire son parent via jellyApiProvider dans le module ; aucun changement des providers existants.
- [ ] Vérifier l'identité active avant et après les opérations asynchrones et avant toute sauvegarde. Un ancien choix invalidé est affichable mais jamais traité comme exact.
- [ ] Relancer les tests ; relire et commiter seulement les fichiers de cette tâche.

## Tâche 4 — Panneau utilisable et raccordement aux fiches

**Files:** créer `anilist_mapping_dialog.dart`, `test/anilist/mapping_dialog_test.dart` ; modifier les trois fiches de détail, les ARB anglais/français et leurs sorties générées ; attribution ciblée dans NOTICE.

**Interfaces:** consomme exclusivement les providers de la tâche 3 pour l'état et les actions. Ouvre des URLs AniList construites depuis un ID entier validé avec le lanceur existant.

- [ ] Écrire les tests widget avec providers remplacés : chargement, lien exact, ambiguïté même avec un seul candidat non prouvé, absence de lien, panne avec réessai, sélection manuelle, confirmation et retrait. Aucune sauvegarde avant confirmation explicite.
- [ ] Tester au clavier les champs, candidats et boutons ; focus visible, lecture des libellés, fermeture et changement de profil pendant une recherche. Tester un titre très long et une liste de candidats vide.
- [ ] Écrire les tests d'intégration des actions film/série/saison, puis lancer `fvm flutter test test/anilist/mapping_dialog_test.dart` et constater l'échec avant implémentation.
- [ ] Réutiliser GlassDialog, les jetons et les contrôles focalisables existants. Afficher le type de correspondance et sa source ; conserver recherche et sélection lors d'une erreur. Aucun switch de synchronisation ou login ajouté.
- [ ] Ajouter ItemActionButton dans les listes d'actions existantes : film et série après les informations techniques ; saison avant generateActions. Conserver les exclusions et les callbacks de suppression existants.
- [ ] Ajouter des clés préfixées anilist aux ARB anglais/français ; générer les localisations. Pour les autres locales, conserver le repli anglais et signaler les traductions restantes, sans inventer de traductions.
- [ ] Exécuter `fvm flutter test test/anilist`, puis `fvm flutter test`, `fvm flutter analyze`, `git diff --check` et `fvm flutter build linux --profile`.
- [ ] Vérifier le diff : aucun changement du lecteur, des providers/modèles/wrappers existants ni des tests/goldens de stabilité précédents. L'analyse existante comporte déjà 4 warnings et 45 infos : comparer les diagnostics, pas seulement le code de sortie.
- [ ] Ouvrir Kinos normal et vérifier un film, Death Note, Naruto Shippuden et une série à plusieurs cours ; confirmer/retrait d'un lien, redémarrage et changement de profil. Ne modifier aucun état de lecture distant.
- [ ] Relire le diff final puis commiter seulement le lot AniList ; ne pas pousser sans demande.

## Auto-relecture du plan

Chaque exigence du cadrage est couverte : exactitude/conflits (1), service et cache hors UI (2), profil/empreinte (3), accès utilisateur et clavier (4). Les cinq risques de Review Focus ont chacun un test explicite. Aucun chantier de suivi, refonte du lecteur, table supplémentaire ou dépendance nouvelle n'est inclus.
