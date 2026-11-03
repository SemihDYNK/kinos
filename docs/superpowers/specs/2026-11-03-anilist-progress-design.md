# AniList : plages et progression

Plan fonctionnel approuvé dans la conversation : automatique quand les sources
concordent, correction mémorisée des ambiguïtés, connexion navigateur et suivi
après validation du visionnage. Pas d'import historique massif ni de notes.

## Correspondance

Un plan contient plusieurs plages : saison Jellyfin, premier/dernier épisode,
fiche AniList, premier épisode AniList. Une plage inconnue ou contradictoire ne
produit aucun envoi. Les plans TMDB et TVDB sont examinés séparément : une
correspondance d'épisode commune est utilisable ; deux destinations différentes
nécessitent une correction. Un offset absent n'est utilisable comme début à 1
qu'avec un nombre d'épisodes AniList connu et une plage sans chevauchement.
Les spéciaux, épisodes sans numéro, correspondances incomplètes et doubles
épisodes traversant deux fiches restent manuels. Les choix manuels de titre du
premier lot ne prouvent pas une plage. Plans manuels isolés par série/profil/
serveur, empreinte des IDs sources et version de la convention.

## Compte et envois

Client public Kinos 55890. Flux officiel Implicit/Auth Pin : navigateur puis
copie du jeton dans le champ masqué ; pas de secret client embarqué. Vérifier
Viewer avant sauvegarde dans flutter_secure_storage, par profil Jellyfin.
Le lien ne transmet que client_id et response_type=token ; la redirection pin
est enregistrée dans les paramètres du client AniList. Le paramètre explicite
redirect_uri provoquait unsupported_grant_type ; le lien minimal a été validé
dans le navigateur de l'utilisateur le 3 novembre 2026.
Activation explicite du suivi. Déconnexion coupe les envois et supprime les
intentions pour ce compte ; aucun secret en Settings/logs.

Après un rapport stop traité (chemin direct ou reprise playback_queue),
inscrire une intention locale durable. Worker distinct du lecteur : rafraîchir
l'état Jellyfin ; ne transmettre que les épisodes marqués vus. Lire la liste
AniList et avancer seulement les épisodes vus contigus depuis sa progression
actuelle. Ne pas diminuer la progression ni modifier les notes, rewatch ou
statuts manuels paused/dropped/planning ; conserver ceux-ci et ne compléter
qu'une entrée nouvelle/current ayant tous ses épisodes. Retry réseau avec
backoff et Retry-After ; 401/403 demandent reconnexion. Vérifier profil ET
compte après chaque await, fermer le client au changement. Un compte différent
ne reprend jamais les intentions de l'ancien. Une provenance locale lie chaque
rapport au serveur, profil, compte et à la génération de connexion : aucun
ancien rapport sans cette preuve ne déclenche de suivi. Le mode incognito
suspend le worker. Les écritures de connexion restent actives si le dialogue
est fermé pendant la sauvegarde, puis libèrent leur état occupé.

## Impact exact

Nouveau code sous lib/anilist/. Settings Drift existant pour plans et intentions
(non secrètes), sans nouvelle table. Deux petits raccords dans
lib/providers/service_provider.dart et playback_report_queue_provider.dart,
nécessaires car le chemin direct efface lui aussi playback_queue. Démarrer le
worker en arrière-plan dans base_app_wrapper ; entrée paramètres du profil et
éditeur depuis le panneau AniList. Aucun changement du moteur vidéo ni des
modèles existants.
