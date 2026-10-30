# Fixtures visuelles de l’accueil

Les PNG de référence sont produits par les vrais widgets Flutter dans
`test/widgets/home_visual_test.dart`. Ils utilisent des données locales fictives,
le thème Kinos, les polices embarquées et le même contenu d’un rendu à l’autre.
La photographie répétée sert à vérifier les proportions et la composition ;
ce n’est pas une bibliothèque de films à livrer dans l’application.

`coast.png` a été généré avec l’outil intégré ImageGen le 27 octobre 2026.
Prompt exact :

> Generate a cinematic film still ONLY, absolutely no UI, text, typography,
> logos, frames, controls, or watermark. Wide 16:9 landscape. A solitary
> traveler in a dark burgundy coat at far right on a black volcanic coast,
> turbulent teal ocean, monumental rugged cliffs on the right, warm amber
> dusk light breaking through storm clouds. Photorealistic cinema, nuanced
> teal and amber photography, rich colors, subtle grain. Left half negative
> space with dark sea and cloud shadows suitable behind later UI text.
> This is illustrative artwork for local UI test fixtures, not a movie
> poster. No letters anywhere.

Cette image n’est pas une capture de maquette. L’interface est entièrement
rendue par Flutter. Le test de contraste utilise aussi un fond blanc extrême,
indépendamment de cette photographie. Les tests géométriques vérifient les
ratios réels et le texte à 100 % et 150 %.

Régénérer les références après examen visuel uniquement :

```sh
fvm flutter test --update-goldens test/widgets/home_visual_test.dart
```
