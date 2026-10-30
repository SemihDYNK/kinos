# Kinos — repères produit

Kinos est un client Jellyfin pour Linux desktop, fork de Fladder sous
GPL-3.0-only. Il couvre films et séries, sur un serveur avec plusieurs profils.

Jellyfin fournit bibliothèque, recherche, fiches et lecture. La bibliothèque
alimente les recommandations calculées localement.
Arr (Sonarr/Radarr), selon configuration, apporte file de téléchargement,
calendrier et recherche interactive de releases. Seerr (Overseerr/Jellyseerr)
permet de découvrir des titres absents, demander leur ajout et suivre les
demandes, avec gestion admin ; il est visible seulement si le profil actif
dispose de ce service. Une maquette n’autorise pas de fonction supplémentaire.

Le bureau est prioritaire : souris, clic droit, clavier directionnel et focus
visible sur toute interaction. La double densité `AppDensity.desk` / `couch`
prépare le mode salon ; sa présence dans le thème ne prouve pas une bascule
de bout en bout. Musique, Live TV, livres, photos, SyncPlay et contrôle à
distance restent hors périmètre.

La direction visuelle est décrite dans `DESIGN.md`. Elle préserve les sources
de données, rangées configurées et destinations existantes. Riverpod porte
l’état, Drift la base locale, `playback_queue` les rapports de lecture et
`flutter_secure_storage` les secrets Jellyfin, Arr et Seerr.

Sur Linux, mpv et `gpu-next` sont imposés. Le rendu reste SDR avec tonemapping
libplacebo, sans chemin HDR passthrough. Le profil natif reste permissif sans
`codecProfiles`. Préserver les couches providers/modèles/wrappers proches de
l’amont : une évolution visuelle ne justifie pas de restructurer les données.
