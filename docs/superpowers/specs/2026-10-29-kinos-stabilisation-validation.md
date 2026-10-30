# Kinos — stabilisation, premier lot

29 octobre 2026. Travail sur Kinos normal ; Lab Plezy/Plex laissé de côté.

## Bilan initial

- Suite complète : 818 réussites, 3 échecs de comparaison visuelle.
- Analyse : 41 diagnostics, sans erreur de compilation.
- Écarts visuels inspectés par comparaison référence/rendu : espacements du
  rail déplié et contours des menus audio, bureau et texte agrandi. Aucun
  débordement dans ces rendus. Seules ces trois références ont été remplacées.

## Corrections

- Le convertisseur Seerr ne recaste plus un corps brut en tentant de gérer
  une erreur. Les corps vides typés et les réponses malformées produisent
  une erreur contrôlée ; les réponses 204/205 et les corps nuls autorisés
  gardent leur signification. Les données invalides ne sont pas imprimées.
- Chopper effaçant les erreurs de conversion des réponses 2xx, son exception
  de transport d’erreur est interceptée dans `SeerrRequest` pour restaurer
  le code HTTP réel et l’erreur, sans fabriquer de statut serveur.
- Les deux accès à `apiResult` vérifient aussi l’erreur de conversion.
  L’accès synchrone lit `this.body` : le nom nu désignait l’annotation
  `body` exportée par Chopper, pas le contenu de la réponse.
- Une requête Seerr est bornée à 30 secondes, corps de réponse compris.
  L’expiration déclenche l’annulation HTTP, conserve un déclencheur
  d’annulation préexistant et ne lance aucune nouvelle tentative.
- Un import inutilisé dans un test Arr est retiré.

## Validation

- Suite complète : **828 tests réussis**.
- Après suppression du cast devenu inutile : les deux tests API repassent.
- Analyse finale : **40 diagnostics de style**, aucune erreur ni avertissement.
- Compilation Linux optimisée : **réussite** (`fvm flutter build linux --profile --no-pub`).
- `git diff --check` : réussite.
- Les tests reproduisent les erreurs de conversion, leur passage dans le
  service réel avec transport simulé, les faux succès API, les corps JSON
  nuls et l’expiration pendant la connexion ou la réception du corps.
- Transport et données de test synthétiques : aucune demande réelle envoyée.

## Limites et suite

Le profilage interactif de la fluidité, une lecture réseau et la validation
sur les vrais serveurs Jellyfin/Seerr restent à faire. La présentation des
messages d’erreur HTTP non-2xx Seerr reste à simplifier. Les diagnostics de
style restants ne sont pas assimilés à des pannes de fonctionnement.

Après une expiration d’une écriture, le serveur peut avoir reçu la demande :
le client ne la répète pas automatiquement. Aucun identifiant ni schéma de
base n’a changé. Les corrections nécessitent un nouveau lancement de Kinos.

Logs : `/tmp/kinos-stabilisation-tests-final.log`,
`/tmp/kinos-stabilisation-analysis-final.log`,
`/tmp/kinos-stabilisation-build-final.log`.
