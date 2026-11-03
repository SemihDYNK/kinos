# AniList Progress Implementation Plan

**Goal:** Mettre en œuvre le plan approuvé : plages automatiques/corrigées, compte
AniList, envois fiables sans ralentir le lecteur.
**Architecture:** Module AniList séparé ; calcul pur, stockage local Settings,
identifiants dans le coffre, worker indépendant déclenché depuis playback_queue.
**Spec:** ../specs/2026-11-03-anilist-progress-design.md
**Execution:** Native dans cette conversation, autorisée par l'utilisateur.

## Tâches et vérifications

- [x] Tests puis episode_mapping.dart : séries multi-parties, offsets inconnus,
  sources contradictoires, numérotation absolue, doubles épisodes, trous dans
  les vus, plages manuelles et dépassements. Pas de mutation sur ambiguïté.
- [x] Tests puis episode_store.dart : plans versionnés, empreintes, isolation,
  file persistante coalescée, acquittement conditionnel et backoff.
- [x] Tests puis API authentifiée / anilist_account.dart : Viewer, droits,
  OAuth URL, stockage sécurisé, déconnexion, progression et statuts sans notes.
- [x] Tests puis anilist_progress.dart/runtime : lecture des états vus, reprise,
  monotonie, annulation et protection profil/compte ; pagination Jellyfin.
- [x] Raccorder les deux sorties playback_queue, démarrer le worker en tâche de
  fond ; préserver le mode incognito et les retours de lecture existants.
- [x] Paramètres compte + éditeur de plages glass, traduction fr/en, clavier.
- [x] Validation finale : tests ciblés et suite complète (911 réussis), analyse
  du module sans diagnostic, revue indépendante et build Linux profile réussis.
  Les fichiers amont raccordés conservent 35 diagnostics info préexistants.
- [ ] Vérification OAuth et premier envoi réels avec participation utilisateur ;
  aucune mutation de son compte pour les tests automatiques.

## Diagnostic connexion — 3 novembre 2026

Le lien minimal OAuth fonctionne dans le navigateur utilisateur. La connexion
reste à valider : le message de reprise réseau masquait toutes les exceptions
du dialogue. Les erreurs de validation API (avec statut HTTP uniquement), refus
du jeton GraphQL et échec de sauvegarde locale sont désormais distingués. Aucun
jeton ni corps de réponse serveur ne sont affichés dans les diagnostics.
Tests AniList : 64 réussis ; analyse du module sans diagnostic.
