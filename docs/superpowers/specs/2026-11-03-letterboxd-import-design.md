# Import Letterboxd

Importer le ZIP officiel dans Paramètres > Profil. Les films vus, notes et revisionnages enrichissent uniquement le profil de goût ; aucun ajout aux candidats, aucune écriture de visionnage Jellyfin ou vers Letterboxd.

## Données et sûreté

Lire watched.csv, ratings.csv et diary.csv, y compris CSV UTF-8 avec BOM, guillemets, virgules et sauts de ligne. Ignorer watchlist, listes et critiques. Ne jamais extraire le ZIP sur disque. Borner archive/CSV et nombre de films ; refuser les en-têtes incohérents et données invalides sans toucher à l'ancien import. Date d'activité de watched.csv/ratings.csv distincte de Watched Date du journal ; seule la seconde date les visionnages.

Dédoublonner par URI de film Letterboxd, puis par identité TMDB lors de l'intégration. Notes de 0,5 à 5 par demi-étoile. Les multiples entrées de journal décrivent des revisionnages, pas autant de votes indépendants.

## Correspondances

D'abord titre/original + année exacts dans les films Jellyfin déjà chargés par les providers existants. Sinon réutiliser les métadonnées du précédent import, puis recherche Seerr et détails avec le client borné existant. Ne pas reconnaître automatiquement les homonymes ambigus. Présenter les correspondances et choix possibles dans l'aperçu ; les titres non reconnus sont conservés mais ne contribuent pas. Une panne réseau permet un aperçu partiel explicite, sans détruire l'ancien import. Annulation et changement de profil interrompent le travail.

## Persistance et scoring

Un instantané versionné dans la table Settings Drift existante, espace serveur/profil explicite, remplacement atomique et suppression locale. Aucun nouveau tableau ni migration. Le flux du snapshot invalide uniquement les recommandations observées.

WatchEvent reçoit un poids explicite facultatif, sans changer les signaux existants. Une note donne (note - 3) * 0,75 ; un revisionnage renforce uniquement les poids positifs, bornés à 2. Les événements sans note gardent les poids existants. Une même œuvre ne contribue qu'une fois entre Jellyfin et Letterboxd ; la note explicite prime, sinon le signal le plus fort est conservé. Aucune modification des ensembles de candidats. Le calcul reste paresseux et la page d'accueil ne dépend pas du réseau d'import.

## Interface

Dialogue frosted glass, choix ZIP, progression, annulation, aperçu avec compteurs et liste construite à la demande, validation explicite et retrait confirmé. Toutes les actions au clavier, messages français/anglais localisés, aucune donnée de compte distante ni secret demandé.

## Vérification

Tests de vrai ZIP synthétique, CSV complexes/invalides, dates, notes, doublons, homonymes, enrichissement hors bibliothèque, panne/annulation, reimport atomique, séparation des profils, poids négatifs, absence de doublons et absence de nouveaux candidats. Tests du dialogue avec sélecteur de fichier injectable. Analyse ciblée et build Linux profilé. L'export réel de l'utilisateur reste à valider lorsqu'il est fourni.
