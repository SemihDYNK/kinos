# AniList — première étape : correspondances fiables

## But et limites

Associer les films d'animation et les saisons/séries Jellyfin aux bonnes fiches
AniList, avec une origine vérifiable et une correction manuelle possible.
Cette étape prépare le suivi : aucune connexion OAuth, mutation AniList,
modification de progression/notes, ni modification des métadonnées Jellyfin.

L'identité d'une œuvre et la correspondance de ses épisodes sont distinctes.
Un lien vers une fiche AniList ne signifie jamais que la progression peut déjà
être synchronisée. Les offsets et plages d'épisodes attendront un lot dédié.

## Constat dans Kinos

- Aucune intégration AniList existante.
- MovieModel/SeriesModel et OverviewModel conservent déjà ProviderIds ;
  SeasonModel/EpisodeModel fournissent les numéros Jellyfin.
- La table Drift Settings et ses méthodes getSetting/setSetting/deleteSetting
  permettent déjà de conserver des associations choisies par l'utilisateur.
- http, flutter_cache_manager, Riverpod et les composants glass/focus existent.
- Les corrections du lecteur sont validées et restent séparées de ce chantier.

## Approches étudiées

1. Seulement les IDs AniList/MyAnimeList déjà présents : simple et exact,
   mais insuffisant pour les bibliothèques identifiées par TMDB/TVDB.
2. IDs directs puis table publique de correspondances : recommandée, permet
   de garder une preuve et d'exposer les correspondances multiples.
3. Recherche par titre automatique : écartée pour la validation automatique ;
   les titres AniList ne sont pas uniques. Recherche sur action utilisateur
   uniquement pour corriger ou compléter un lien.

## Résolution proposée

- Lire les IDs sans dépendre de leur casse. Valeurs positives et valides
  seulement ; conserver IMDb comme texte, avec son préfixe tt.
- Une association manuelle enregistrée prime pour son objet et son profil.
- Un ID AniList explicite est vérifié par l'API Media(type: ANIME).
  Un ID MyAnimeList peut être résolu avec Media(idMal: ..., type: ANIME).
- À défaut, utiliser Fribb/anime-lists : AniDB, MAL, IMDb, TVDB et TMDB.
  TMDB film et TMDB série restent deux espaces d'identifiants distincts.
- Des IDs de fournisseurs différents qui désignent des fiches différentes
  produisent un conflit visible, jamais un choix silencieux de la première.
- Plusieurs fiches pour un même ID de série produisent des candidats. Le
  numéro de saison ne filtre que si la source fournit cette information
  et si son référentiel est établi. Une saison TMDB n'est pas supposée égale
  à une saison TVDB ; un numéro absent n'est jamais remplacé par zéro.
- Ne pas appliquer l'ID AniList de la série parent à toutes ses saisons.
  Un ID direct de série établit un lien d'œuvre, pas un lien d'épisode.
- Résultats explicites : lien exact, plusieurs candidats à confirmer,
  aucun lien, service temporairement indisponible. Conserver la provenance.
- Ne pas déduire des saisons ou offsets depuis les noms de fichiers. Les
  épisodes Jellyfin mal classés en saison 0 restent signalés, non corrigés.

## Parcours visible de ce lot

Ajouter aux actions des fiches film/série/saison une entrée « AniList ».
Sur action utilisateur, un panneau glass montre le lien et sa provenance,
ou les candidats avec leurs titres et dates ; une recherche manuelle permet
un choix explicite. On peut ouvrir la fiche AniList, confirmer un lien ou
retirer l'association locale. Aucun envoi de progression n'est disponible.

Navigation directionnelle et focus visible sur toutes les actions. Une erreur
réseau conserve le panneau et permet de réessayer. L'accueil et le lecteur ne
lancent pas cette résolution et n'attendent jamais son résultat.

## Données, cache et réseau

Le fichier Fribb consulté pendant l'étude contient 39 597 entrées et occupe
7 512 806 octets. Ne pas le charger/analyser dans build(). Téléchargement à
la première utilisation, cache de fichier via la dépendance installée,
rafraîchissement après 24 h, dernier fichier valide conservé en cas d'échec.
Décodage et création des index hors de l'isolate UI. Une seule tâche de
chargement à la fois ; pas de téléchargement à chaque fiche.

Ne pas intégrer le catalogue complet dans le dépôt ou le binaire. Ajouter
l'attribution des sources ; vérifier les conditions de redistribution lors
de la préparation de la version distribuable.

L'API publique AniList ne sert qu'à consulter une œuvre et à la recherche
manuelle, jamais à reconstruire son catalogue. Une seule requête à la fois,
intervalle minimal de deux secondes, délai maximal de quinze secondes,
respect de Retry-After sur 429, pas de boucle de relances illimitée. Utiliser
les variables GraphQL ; distinguer les erreurs GraphQL d'un HTTP 200 valide.

Les associations manuelles sont des préférences non secrètes dans Settings,
avec scope dérivé du serveur et du profil actifs, puis clé d'objet Jellyfin.
Le lien d'une saison a sa propre clé. Garder une empreinte des IDs sources :
si les métadonnées changent, demander une nouvelle confirmation au lieu de
réutiliser silencieusement un ancien choix. Aucune nouvelle table, donc
aucune migration Drift dans ce lot. Aucun jeton de connexion n'est demandé.

## Impact prévu, avant toute modification de la couche protégée

Nouveau module lib/anilist/ : adaptation des métadonnées, résolution, client
public, cache et providers autoDispose. Réutiliser appDatabaseProvider pour
les préférences ; fermer les requêtes liées à la fiche et invalider ses
résultats lors du changement de profil. Le catalogue public peut être partagé
entre profils ; leurs choix manuels restent strictement séparés.

UI : panneau partagé et entrées d'action dans les fiches film, série et
saison, en réutilisant le routage et les composants existants. Ajouter les
textes aux ressources de localisation, puis régénérer les sorties.

Aucune modification prévue de lib/providers/, lib/models/, lib/wrappers/,
du moteur de recommandations, de playback_queue ou du lecteur. Si l'étude
d'implémentation révèle un champ manquant, décrire l'impact exact avant de
modifier ces dossiers, conformément aux règles du fork.

## Vérification attendue

Tests unitaires : casse et IDs invalides ; film/série TMDB partageant le même
nombre ; correspondance unique ; conflits entre fournisseurs ; doublons ;
MAL direct ; saison absente contre saison 0 ; série longue sans saison dans
la source ; plusieurs cours ; données de catalogue partielles/corrompues.

Tests réseau simulés : erreur HTTP, HTTP 200 avec erreurs GraphQL, 429,
expiration, annulation et fermeture. Tests de préférences : isolation
serveur/profil, retrait, changement d'IDs, conservation après redémarrage.

Tests de widget : panneau au clavier, choix manuel explicite, erreurs et
états vides. Validation réelle sur un film, Death Note, Naruto Shippuden et
une série à plusieurs cours : vérifier les liens sans écrire de progression.

## Sources consultées

- https://github.com/Fribb/anime-lists — schéma du catalogue et limites de saison.
- https://docs.anilist.co/guide/graphql/queries/media — identité et recherche.
- https://docs.anilist.co/reference/query — Media(idMal: ...).

## Suite hors de ce lot

Après validation des identités : correspondance explicite des épisodes,
puis authentification et règles de synchronisation choisies avec l'utilisateur.

## Précision utilisateur : saisons divisées (JoJo)

Une saison TVDB peut correspondre à plusieurs fiches AniList. Conserver les
numéros de saison par source et `episode_offset` par candidat, sans assimiler
un décalage absent à zéro. Exemple réel : TVDB 262954 saison 2 correspond à
AniList 20474 et 20799, avec un décalage TVDB de 24 pour la deuxième partie.
Le panneau affiche cette ambiguïté. Une confirmation locale identifie une
fiche uniquement : elle ne valide pas la couverture des épisodes d’une saison.
La future synchronisation devra résoudre les plages avant toute transmission.
