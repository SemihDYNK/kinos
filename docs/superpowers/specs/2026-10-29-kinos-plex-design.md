# Kinos — premier parcours Plex

Statut : proposition technique issue de la reconnaissance, à valider avant le plan d'implémentation.

## Objectif et périmètre

Permettre à un profil Kinos d'utiliser Plex à la place de Jellyfin, avec la même interface Linux et le même lecteur mpv. Un serveur actif par profil ; plusieurs profils possibles. Ne pas fusionner les catalogues de plusieurs serveurs.

Premier lot : connexion Plex dans le navigateur, choix du serveur, bibliothèques films/séries paginées, fiche film/série/saison/épisode, lecture directe, sélection audio/sous-titres, reprise, suivi démarrage/progression/arrêt et état vu. Les états vides, erreurs et reconnexion font partie du lot.

La recherche, les recommandations personnalisées, les fonctions Plex avancées, le téléchargement et le transcodage Plex ne sont pas annoncés comme disponibles dans cette première tranche. Leurs commandes doivent être masquées ou clairement indisponibles dans un profil Plex, sans modifier leur fonctionnement Jellyfin. Seerr Plex constitue le lot suivant, une fois l'identité du profil stabilisée.

Contraintes conservées : mpv/gpu-next sous Linux, SDR avec tonemapping actuel, aucune voie HDR/passthrough, aucun codecProfiles ajouté au profil Jellyfin. Aucun secret hors stockage sécurisé. Aucun appel serveur depuis les widgets.

## Options étudiées

1. Dupliquer les écrans pour Plex : rapide au début, mais double maintenance des fiches, animations et correctifs. Écartée.
2. Remplacer tous les modèles/providers par ceux de Plezy : migration importante et divergence excessive avec Fladder. Écartée.
3. Connecteurs séparés, interface commune limitée au parcours livré, convertisseurs vers les modèles d'affichage Kinos et migration progressive des appelants : recommandée.

Les réponses Plex ne doivent pas être transformées en faux DTO Jellyfin. Les particularités de transport restent dans le connecteur. L'interface commune ne doit pas devenir une copie de toutes les méthodes de JellyService.

## Inspiration vérifiée

Plezy officiel, copie temporaire en lecture seule, commit `1dd75b3e5e95913cdaa5b8c22911490e72dfb7c5` :

- `lib/media/media_server_client.dart` : contrat commun de navigation, actions et rapports de lecture.
- `lib/services/plex_client.dart` et `lib/services/jellyfin_client.dart` : implémentations distinctes.
- `lib/media/media_item.dart` et `lib/services/jellyfin_mappers.dart` : modèles communs avec particularités conservées.
- `lib/services/plex_auth_service.dart` : PIN, navigateur, interrogation du PIN et découverte des serveurs.
- `lib/media/server_capabilities.dart` : fonctionnalités disponibles par serveur.
- `lib/services/playback_source_resolver.dart` et `playback_report_session.dart` : préparation de lecture et rapports indépendants des écrans.

Source : https://github.com/edde746/plezy . Son code n'a pas été exécuté. Si du code est repris, conserver ses mentions d'auteur/licence et mettre à jour NOTICE après revue des fichiers effectivement importés.

## Reconnaissance Kinos et impacts requis

68 fichiers non générés de `lib/` référencent `jellyApiProvider` au moment de l'audit. Ce nombre mesure un couplage, pas le nombre de fichiers à réécrire dans ce lot.

| Zone existante | Constat | Adaptation nécessaire |
| --- | --- | --- |
| `lib/models/account_model.dart` | Identité = serveur + utilisateur ; permissions/configuration de type Jellyfin | Ajouter le backend avec valeur historique Jellyfin ; préserver les champs Jellyfin ; capacités communes distinctes des DTO de configuration |
| `lib/models/credentials_model.dart` | Produit un en-tête MediaBrowser | Ne pas utiliser cet en-tête pour Plex ; sérialisation compatible des anciens comptes et identifiants Plex séparés du transport Jellyfin |
| `lib/services/secure_credentials_store.dart`, `lib/providers/shared_provider.dart` | Clés serveur/utilisateur ; migration et lecture du coffre existantes | Identité incluant backend pour les nouveaux profils ; lecture des clés historiques et migration idempotente sans suppression avant vérification |
| `lib/screens/login/login_screen_credentials.dart` et `lib/providers/auth_provider.dart` | Authentification et association Seerr orientées Jellyfin | Choix de serveur, flux Plex distinct, annulation/expiration/refus et sélection du serveur ; ne pas appeler authenticateJellyfin pour Plex |
| `lib/providers/user_provider.dart` | Rafraîchit le compte via JellyService et des paramètres Jellyfin | Branche Plex explicite ; ne pas interroger la configuration administrateur Jellyfin pour un profil Plex |
| `lib/providers/views_provider.dart`, `lib/providers/library_search_provider.dart` | Bibliothèques et requêtes dépendent du service Jellyfin | Faire passer les opérations livrées par le contrat commun ; pagination et tri traduits par connecteur |
| `lib/models/item_base_model.dart`, `lib/models/items/{movie,series,season,episode}_model.dart` | Modèles d'affichage existants, fabriques depuis BaseItemDto et champs particuliers Jellyfin | Ajouter des convertisseurs Plex vers les formes Kinos réutilisables ; audit des champs obligatoires, droits, images et unités ; aucun appel réseau dans un modèle |
| `lib/providers/items/{movies,series,episode}_details_provider.dart` | Chargement des fiches via JellyService | Déléguer le parcours commun ; ne pas lancer les enrichissements Jellyfin dans la branche Plex |
| `lib/models/playback/playback_model.dart`, `direct_playback_model.dart`, `lib/providers/video_player_provider.dart` | Modèle de lecture contient des types Jellyfin et rapports via JellyService | Modèle de lecture Plex dédié respectant le contrat consommé par mpv ; source, en-têtes et pistes résolus par le connecteur |
| `lib/models/syncing/playback_queue_table.dart`, `database_item.dart`, `lib/providers/playback_report_queue_provider.dart` | Outbox persistante, positions en ticks, envoi via endpoints Jellyfin ; filtrage par userId | Ajouter une identité backend/serveur/profil et un routage des rapports ; migration Drift obligatoire ; conserver la file et son backoff |
| `lib/wrappers/players/lib_mpv.dart` | Consomme PlaybackModel et modèles de pistes | Réutiliser le moteur ; ne modifier que les points nécessaires révélés par le test de lecture, pas ses réglages GPU |
| Écrans, navigation et actions | Certaines fonctions impliquent des droits/options Jellyfin | Afficher les commandes selon les capacités réellement implémentées ; focus directionnel et menus conservés |

Cette cartographie décrit les zones requises. Les fichiers générés correspondants seront régénérés avec les outils existants ; jamais édités à la main.

## Structure proposée

Créer un dossier isolé `lib/plex/` pour authentification, transport, modèles de réponse et convertisseurs Plex. Ajouter une frontière commune minimale sous `lib/media_servers/` : identité, capacités, opérations de bibliothèque/fiches et préparation de lecture. Garder Riverpod pour l'état et sélectionner le connecteur depuis le profil actif.

Le connecteur Jellyfin délègue à JellyService au lieu de le réécrire. Déplacer seulement les appelants nécessaires au parcours livré. Aucun changement dans le Swagger Jellyfin pour y faire entrer Plex.

Les identifiants de contenu restent opaques : ne jamais convertir un identifiant Plex en identifiant TMDB/Jellyfin. Les identifiants externes sont des métadonnées séparées. Les caches et images doivent tenir compte de l'identité du serveur ; les jetons ne doivent jamais être affichés dans les logs.

## Authentification et isolation

Le navigateur reçoit la page d'autorisation Plex ; Kinos ne demande pas le mot de passe Plex. L'interrogation du PIN s'arrête après succès, annulation ou expiration et lors de la destruction de l'écran. Le serveur choisi fournit une identité et une connexion validées ; aucune préférence systématique pour une URL non vérifiée.

Les tokens sont gardés dans flutter_secure_storage. Les références publiques du profil restent sérialisables sans secret. La déconnexion révoque l'état local actif et ferme le connecteur ; les requêtes d'un ancien profil ne doivent jamais alimenter le nouveau.

Pour les anciennes entrées locales sans backend/serveur, ne pas deviner une attribution ambiguë. Préserver les données historiques et les rendre accessibles seulement lorsque l'attribution Jellyfin est démontrable ; sinon les conserver en attente de résolution. Aucune entrée historique ne doit être envoyée à Plex par défaut.

## Lecture et progression

Réutiliser mpv, les commandes et les animations existantes. La préparation fournit URL, en-têtes, durée, position de départ et pistes. Convertir les unités aux frontières : Plex et Jellyfin ne doivent pas partager un entier de position sans unité définie.

Tous les rapports passent par playback_queue. L'envoi choisit le connecteur correspondant à l'identité enregistrée, pas simplement au profil actuellement affiché. Conserver l'ordre démarrage/progression/arrêt et le traitement des erreurs ; vérifier qu'un changement de profil ne provoque ni mauvaise attribution ni perte de rapports.

Le lecteur Plex annonce seulement les modes effectivement disponibles. Une lecture nécessitant un transcodage non livré doit produire un message explicite, sans boucle de chargement. Le suivi d'état vu doit être testé sur Plex pour éviter les doubles écritures.

## Capacités et cohérence UI

Plex n'expose pas dans Plezy un favori utilisateur équivalent au cœur Jellyfin. Dans ce lot, masquer le cœur pour les profils Plex plutôt que le transformer silencieusement en note ou watchlist. Un favori local serait une fonctionnalité distincte à décider.

Masquer également les réglages administrateur Jellyfin et les options de lecture non implémentées. Aucun changement esthétique des pages existantes. Une bibliothèque Plex doit bénéficier des mêmes grilles virtualisées, images, transitions et navigation clavier.

## Validation avant livraison

- Régression de connexion, lecture, progression et changements de profils Jellyfin.
- Tests de migration des comptes, du coffre et de Drift, avec anciens formats réels simulés et collisions d'identifiants entre serveurs/backends.
- Tests d'authentification Plex : succès, expiration, annulation, token refusé, absence de serveur et URL inaccessible ; secrets expurgés des erreurs.
- Tests de conversion film/série/saison/épisode, images manquantes, dates/durées/pistes et identifiants externes.
- Tests de pagination, erreurs réseau, collections vides et invalidation du profil actif.
- Tests de l'outbox : isolation, unités, ordre des rapports, reprises après panne et absence de double état vu.
- Tests des capacités UI et parcours directionnel avec grandes tailles de texte.
- Compilation Linux profile ; validation sur un véritable serveur Plex avec film et épisode, audio/sous-titres, pause, seek, fermeture puis reprise.

Aucun token réel ni serveur Plex n'a été utilisé dans cette étude. La validation sur serveur est un critère de livraison, pas une hypothèse de compatibilité.

## Séquence et décision suivante

1. Écrire le plan détaillé de migration après revue de cette spécification.
2. Stabiliser identité, migration et frontière commune avec régressions Jellyfin.
3. Brancher authentification et bibliothèques Plex.
4. Brancher fiches, lecture et progression persistante.
5. Valider Linux et serveur réel avant d'étendre recherche/recommandations puis Seerr Plex.

L'ajout de Plex est un changement architectural : aucune modification des providers/modèles n'est incluse dans cette reconnaissance.
