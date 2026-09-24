# Fixtures Seerr

Toutes les fixtures de ce dossier sont **synthétiques** (`*.synthetic.json`)
: écrites à la main d'après la documentation publique de l'API Jellyseerr/
Overseerr et la forme des modèles Dart (`lib/seerr/seerr_models.dart`),
jamais capturées depuis une vraie instance. Aucune ne doit être traitée
comme une réponse réelle.

## À remplacer par de vraies captures

Quand des réponses réelles seront fournies, remplacer ces trois fichiers
en conservant le même nom (les tests qui les chargent n'auront rien à
changer) :

- `discover_trending.synthetic.json` — `GET /api/v1/discover/trending`
- `movie_details.synthetic.json` — `GET /api/v1/movie/<id>`
- `request_created_movie.synthetic.json` — réponse de `POST /api/v1/request`

Les autres fixtures (`tv_details`, `request_created_tv`, `requests_list`)
resteront synthétiques tant qu'aucune capture équivalente n'est fournie —
aucune urgence à les remplacer, elles couvrent des variantes de forme
(TV plutôt que film, page de résultats) plutôt qu'un endpoint distinct.

## Convention

Un fichier `*.synthetic.json` ne devient un fichier "réel" qu'en perdant
ce suffixe — jamais l'inverse. Si un doute existe sur la fraîcheur d'une
fixture, vérifier ce README avant de faire confiance à son contenu.
