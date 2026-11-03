# Letterboxd Import Implementation Plan

**Goal:** Importer l'export ZIP Letterboxd et enrichir le goût sans modifier candidats ou historique serveur.
**Architecture:** Module lib/letterboxd séparé : parseur pur, modèle/liaison, rapprochement et fusion d'événements, stockage Drift existant, providers et dialogue. Branchement dans les trois consommateurs du profil existant.
**Tech Stack:** Dart/Flutter FVM 3.47, archive déjà installé, file_picker déjà installé, Riverpod, Drift, DiscoveryClient existant.
**Spec:** docs/superpowers/specs/2026-11-03-letterboxd-import-design.md

## Contraintes

Aucun changement dans lib/providers, lib/models ou lib/wrappers. Aucun secret, nouvelle table ou dépendance. Aucun appel Jellyfin depuis un widget. Travail d'import annulable, isolé par compte. Aucun commit/push demandé.

## Risques à couvrir

- CSV avec retours ligne et noms homonymes : lecture exacte, jamais de match flou automatique.
- ZIP démesuré ou métadonnées corrompues : limites avant allocation et conservation de l'import existant.
- Changement de profil ou annulation pendant une réponse : aucun résultat tardif enregistré.
- Réimport et éditions multiples d'un même film : un seul signal par œuvre.
- Panne réseau : aperçu partiel et retrait possible, aucune attente ajoutée au rendu de l'accueil.

## Tâches (exécution dans cette session)

- [x] Parseur/modèle — lib/letterboxd/letterboxd_model.dart et letterboxd_parser.dart ; test/letterboxd/parser_test.dart. Tests rouges puis ZIP/CSV bornés, dates/notes et fusion des fichiers.
- [x] Correspondances/fusion — letterboxd_matching.dart ; test/letterboxd/matching_test.dart. Métadonnées Jellyfin/Seerr, choix explicite et dédoublonnage des événements. Tests rouges avant implémentation.
- [x] Stockage/profil — letterboxd_store.dart, letterboxd_providers.dart et letterboxd_import_controller.dart ; tests de stockage/contrôleur. Drift transactionnel et état Riverpod annulable. Pas de migration.
- [x] Scoring — poids facultatif dans lib/recommendations/models/watch_event.dart ; utilisation dans taste_profile_builder et discovery_engine, puis fusion dans recommendation_providers, home_catalog_providers et discovery_providers. Tests prouvant que les candidats ne changent pas et que les poids existants restent identiques.
- [x] UI — letterboxd_import_dialog.dart, entrée profile_settings_page et traductions EN/FR. Aperçu virtuel/choix/confirmation/retrait et tests widget.
- [x] Vérification — tests ciblés puis suite, analyse, revue indépendante et build Linux. Aucune publication automatique.

## Validation réalisée

- 247 tests Letterboxd/recommandations passent, dont le parcours widget de prévisualisation et confirmation.
- Analyse ciblée : aucun problème. Build Linux profile réussi.
- Revue indépendante : sélection Seerr corrigée pour utiliser uniquement les événements Jellyfin initiaux ; les imports restent réservés au scoring.
- Aucun import personnel effectué, aucun compte distant modifié. Lecture du véritable ZIP utilisateur validée le 3 novembre : 707 films et 703 notes, sans persistance. Dossiers deleted/orphaned ignorés ; test de régression ajouté. La confirmation dans l’interface reste à effectuer par l’utilisateur.

### Recherche Seerr — correction du 3 novembre

Le serveur réel retourne HTTP 400 si le paramètre query ne reste pas encodé après le décodage HTTP. LetterboxdResolver encode désormais le titre avec Uri.encodeComponent avant de le transmettre au client HTTP. Vérification autorisée en lecture seule : Toy Story 2 passe de HTTP 400 à HTTP 200 (3 résultats). Test réservé aux caractères espaces/accents/&/+ ajouté ; 31 tests Letterboxd passent et analyse sans problème. Aucun identifiant ni résultat personnel persisté par le diagnostic.

### Films vus et cache — correction du 3 novembre

Les films importés étaient pondérés mais restaient candidats si Jellyfin les considérait non vus. Exclusion ajoutée à Pour vous et aux rangées par goûts, toutes notes confondues, via IDs Jellyfin/TMDB puis correspondance exacte titre/année ; toutes éditions d’une même œuvre sont exclues. Les identités TMDB vues sont aussi exclues de la découverte Seerr. Aucun statut Jellyfin modifié.

Les marqueurs de fraîcheur sont désormais versionnés et isolés par serveur/profil ; les classements précédents sont recalculés. Le cache Pour vous est masqué tant qu’il nécessite un recalcul après import, car ses anciennes tuiles ne contiennent pas les IDs externes permettant une exclusion fiable des titres traduits. Tests du provider réel, du cache par compte, des doublons d’éditions et du fallback widget en attente/échec. 260 tests ciblés passent ; analyse sans problème.

### Boucle de recalcul — diagnostic du 3 novembre

Après navigation prolongée, l’instance utilisait environ 110 % CPU au repos. Le profil CPU montrait notamment home_catalog_providers/buildLibraryTraitStats et de nombreuses reconstructions. Le flux Drift Settings de Letterboxd réémettait un nouvel objet après toute écriture Settings, même d’un autre scope ; les recommandations réécrivaient leur marqueur puis se redéclenchaient. Un test reproduit trois émissions au lieu d’une après deux écritures étrangères. Le flux filtre désormais les valeurs JSON inchangées avant décodage isolé, coupant la boucle sans vider les caches. Le test vérifie aussi qu’une vraie suppression émet encore. 256 tests ciblés passent ; analyse sans problème.

### Registre Découvrir entre vues retenues — correction du 3 novembre

Le correctif Letterboxd ne suffisait pas : le profil CPU du scénario bibliothèque attribuait 17 248/24 309 échantillons aux calculs home_catalog_providers. Deux sections Découvrir retenues par la navigation remplaçaient en boucle un propriétaire unique du registre. Test reproduit : 40 publications sur 20 frames. Registre remplacé par contributions par instance, abonnement limité à sa propre contribution ; inventaire lit leur union. Test vérifie stabilité, union films/séries, retrait d’une section sans effacer l’autre, puis nettoyage complet. Revue indépendante sans finding bloquant. 280 tests ciblés passent, analyse sans problème ; comparaison native en cours.

### Comparaison native après les deux correctifs

Même binaire Linux profile et même machine : dernière mesure CPU post-navigation sur 10 s = 13,3 %, contre 109,8 % sur l’instance défaillante au repos. Sur le parcours corrigé d’une minute, RSS autour de 630 Mo en fin de mesure, tas Dart après collecte = 106 061 312 octets. Pas de croissance continue observée dans cette fenêtre. Kinos laissé ouvert avec journal local /tmp/kinos-ui-stable.log ; stabilité sur une ouverture de longue durée encore à confirmer.

### Récidive et cycle de vie asynchrone — correction du 3 novembre

La comparaison d’une minute ci-dessus était insuffisante : à 5 min 41, le CPU remontait à 110,7 %. Un ProviderObserver indépendant, sans abonnement ajouté, a révélé environ 4 900 destructions/recréations du registre et 9 800 mises à jour d’inventaire. Les dépendances autoDispose étaient observées après des await dans les providers de rangées par goûts et d’inventaire ; leur abonnement disparaissait temporairement à chaque reconstruction, relançant le cycle.

Toutes les dépendances sont maintenant enregistrées avant le premier await ; les calculs devenus obsolètes s’arrêtent avant le scoring. L’aperçu de première page reste progressif et n’attend ni le registre ni les rangées par goûts. Le test de récidive reproduisait 21 démarrages en 20 frames avant correction ; les deux variantes se stabilisent désormais et réagissent une fois à un véritable changement de source. Revue indépendante sans problème identifié. 282 tests ciblés passent ; analyse ciblée sans problème ; build Linux profile normal réussi.

Vérification native de six minutes avec l’entrée diagnostique tool/diagnostics/provider_loop_probe.dart : aucun cycle continu, rafraîchissements terminés par un état stable, aucun échantillon des calculs home_catalog dans le dernier profil CPU (3 729 échantillons). CPU au repos observé à 0–3,4 %, avec pointes de rendu jusqu’à 90,3 % ; ce résultat ne prouve pas l’absence de toute saccade. Tas Dart après collecte : 103 214 944 octets. RSS perturbée par le prélèvement du profil VM, donc non utilisée pour conclure à l’absence de fuite. Version normale reconstruite et rouverte sans observer ; validation de plusieurs heures restant à faire.
