# Clignotement des barres pendant le défilement

## Diagnostic

Les vidéos du 30 octobre montrent des frames où la top bar, la sidebar et
parfois des cartes ne sont pas peintes. Les coordonnées des barres restent
identiques avant/après : il s'agit d'une disparition de calques, pas d'une
animation de déplacement.

Reproduction native isolée, sans compte, réseau, images ou lecteur : Linux,
Xvfb 1280 × 720, Mesa logiciel, build profile, grille de 1 000 cartes, scroll
et survol animé, trois surfaces dépolies. Capture à 30 images/seconde.
Même source minimale compilée avec chaque SDK, backend Linux par défaut :

| Moteur | Essai | Frames examinées | Sidebar absente | Scène vide |
|---|---:|---:|---:|---:|
| Flutter 3.35.7 | 1 | 285 | 92 | 0 |
| Flutter 3.35.7 | 2 | 285 | 83 | 0 |
| Flutter 3.47.0 | 1 | 259 | 0 | 0 |
| Flutter 3.47.0 | 2 | 286 | 0 | 0 |

Avec les vrais composants Kinos (`FrostedSurface`, `PosterHoverMotion`) sous
3.47.0 : deux captures supplémentaires, respectivement 284 et 281 frames,
aucune sidebar absente ni scène vide. La top bar reste également visible
sur les captures inspectées. Le comptage automatique porte sur le marqueur
blanc de la sidebar et la présence de la grille.

L'isolation des panneaux par RepaintBoundary, la suppression du filtre au
survol, la séparation fond/contenu, le blend mode source et une saveLayer de
la scène entière n'ont pas supprimé le défaut sur toutes les répétitions
avec 3.35.7. Ces contournements ne sont pas conservés.

## Correction

- SDK FVM et VSCode : Flutter 3.47.0 stable (Dart 3.13.0). La CI lit `.fvmrc`.
- Dépendances compatibles : font_awesome_flutter 11.0.0 et page_transition
  2.2.2 ; adaptations de l'icône GitHub et des imports RepeatMode des deux
  modèles de lecture. Aucun changement de comportement du lecteur.
- Surface dépolie : Material transparent au-dessus du fond teinté pour que
  l'encre des ListTile reste visible. Le nouveau moteur signalait ce vrai
  défaut par une assertion ; un test dédié le reproduit avant correction.
- Tests de curseur Arr : distinguer le curseur cliquable du MouseRegion
  ajouté par Tooltip dans le nouveau SDK.
- Références visuelles actualisées après inspection des écarts de contours
  arrondis et des menus. Aucun changement des jetons de taille/couleur.

## Reproduction future

`tool/diagnostics/glass_scroll_probe.dart` exécute le scénario avec les vrais
composants Kinos, sans données personnelles. Il se ferme après environ dix
secondes de défilement automatique :

```sh
fvm flutter run -d linux --profile -t tool/diagnostics/glass_scroll_probe.dart
```

Après un build de cette cible, reconstruire l'entrée normale avant d'utiliser
le raccourci Kinos : `fvm flutter build linux --profile`.

## Validation et limites

- 847 tests passent, dont 29 tests de captures.
- Compilation Linux profile validée.
- Analyse : aucune erreur ; 4 avertissements préexistants nouvellement
  signalés par l'analyseur et 45 remarques de style/dépréciation. Pas de
  nettoyage de code sans rapport avec ce défaut.
- Pas de mesure GPU AMD/Wayland ni de lecture vidéo réelle dans cette
  session. La reproduction virtuelle confirme la correction du scénario,
  pas une garantie sur toutes les configurations graphiques.

## Régression lecteur détectée après validation utilisateur

L'utilisateur confirme Seerr et la disparition du bug des barres, puis signale
un crash à chaque lecture. Trois coredumps du 3 novembre (335371, 357192,
357665) montrent un SIGSEGV dans le thread raster de libflutter_linux_gtk.so.
Flutter 3.47 active Impeller par défaut. Le test vidéo local Wayland/Weston
avec mpv produit 123 erreurs « invalid command » avec Impeller ; la même cible
avec Skia termine sans erreur de rendu. Le SIGSEGV exact du GPU AMD n'est pas
reproduit sur Mesa logiciel.

Premier essai, retiré après retour utilisateur :
`fl_dart_project_set_enable_impeller(project, FALSE)`
dans le lanceur Linux, avant création du FlView. Flutter 3.47 et la sortie
vidéo mpv existante sont conservés. Aucun changement de décodage, de profil
Jellyfin ou de paramètres du lecteur.

Validation : lecture du fichier local généré sous Weston/Wayland, progression
et arrêt du lecteur réussis ; 74 tests ciblés passent ; test grille et verre
dépoli sous Xvfb : 268 frames, aucune sidebar absente ni scène vide. La lecture
sur le vrai serveur et le GPU AMD reste à confirmer par l'utilisateur.

Sonde reproductible, sans compte ni serveur :

```sh
ffmpeg -f lavfi -i testsrc2=size=640x360:rate=24 -t 5 -c:v libx264 /tmp/kinos-test.mp4
fvm flutter build linux --profile -t tool/diagnostics/playback_probe.dart
build/linux/x64/profile/bundle/kinos /tmp/kinos-test.mp4
```

La sonde sort avec `PLAYBACK_OK` si la lecture progresse. Vérifier aussi l'image
et les logs natifs : la progression seule ne garantit pas la composition GPU.
Reconstruire ensuite l'entrée normale : `fvm flutter build linux --profile`.

## Correction du partage des textures vidéo

Le retour utilisateur montre la vidéo remplacée par le logo et des éléments
UI corrompus avec Skia. Le premier contrôle était insuffisant : le compteur
progressait sans vérifier les pixels. Test renforcé : une vidéo rouge de cinq
secondes sous Weston imbriqué dans Xvfb, capture FFmpeg, comptage des pixels
rouges et contrôle de la sortie normale du lecteur. L'ancien plugin a zéro
pixel rouge bien que le lecteur sorte avec PLAYBACK_OK.

Cause : l'ancien plugin crée ses textures dans un contexte GDK ; Flutter 3.47
utilise ses propres contextes EGL, non partagés avec GDK. Le fork DonutWare
contient déjà le pont EGLImage compatible. Seul media_kit_video passe de
cb56b5a6 (2.0.0) au commit fixé 7c892d6bec9117fe0ea49277dad88144c659df8a
(2.0.1). media_kit et les bibliothèques mpv restent à leur version verrouillée.
L'API Dart du contrôleur natif est identique. Aucun provider/wrapper modifié.
Le contournement Skia est retiré : Impeller est rétabli.

Trois captures corrigées comptent 746398, 746650 et 746606 pixels rouges,
avec fin de lecture normale et sortie matérielle mpv active dans les logs.
Un premier essai isolé du nouveau plugin a expiré avant la création de la
sortie vidéo ; les répétitions suivantes et le test conservé sont donc requis,
sans qualifier ce premier essai de succès.

Test de pixels conservé :

```sh
fvm flutter build linux --profile -t tool/diagnostics/playback_probe.dart
xvfb-run -a -s '-screen 0 1280x960x24' python3 tool/diagnostics/playback_image_check.py
fvm flutter build linux --profile
```

Dépendances de diagnostic seulement : Xvfb, Weston, FFmpeg, Pillow. Ce test
ne remplace pas une vérification du son, des sous-titres, des changements
d'épisode et du décodage AMD sur le bureau réel.

Validation finale de cette correction : test de pixels conservé réussi
(746526 pixels rouges), 847 tests passent, sonde de défilement : 285 frames,
zéro sidebar absente, zéro scène vide. Analyse : zéro erreur, quatre
avertissements et 45 infos comme avant. La cible normale est reconstruite
après les sondes. Confirmation sur la machine AMD de l'utilisateur requise.

## Retour réel et cycle de vie EGL (17 h)

Le retour utilisateur confirme un autre crash raster identique (384334,
SIGSEGV +0x86537a). Les tests précédents tournaient en Mesa logiciel car
/dev/dri est masqué dans le bac à sable. Hors bac à sable, le GPU réel est
accessible : ne plus déduire son absence à partir du seul contexte restreint.

La sonde a été enrichie du logo SVG Kinos et de trois surfaces dépolies.
Sur RX 6700 XT, via le backend X11/XWayland par défaut, DonutWare 7c892d6
échoue à la libération du lecteur : « No provider of eglDestroyImageKHR »
puis SIGABRT. Ce défaut de cycle de vie est distinct du SIGSEGV raster : ne
pas les confondre. Le PR amont media-kit #1466 gère le contexte propriétaire
des textures, diffère leur suppression dans le bon contexte et résout les
extensions EGL explicitement. Dépendance media_kit_video seule fixée à
freeKC/media-kit 5c533691f0f1d75747b5cdad2456cc09de91ec9b ; le noyau
media_kit et les bibliothèques mpv restent inchangés. Impeller reste actif.

Trois lectures/fermetures de la sonde sur le vrai GPU, XWayland : sortie 0,
PLAYBACK_OK, sortie H/W avec contexte EGL isolé et nom RX 6700 XT vérifiés.
La sonde réelle et ses logs ne suffisent pas à déclarer le parcours complet
du serveur réparé : validation dans Kinos normal requise.

Validation GPU réel supplémentaire : deux essais Wayland natifs réussis,
RX 6700 XT et sortie H/W confirmés dans les logs, en plus des trois essais
XWayland. 847 tests passent ; analyse sans erreur (4 warnings, 45 infos).
Le scénario complet d'ouverture d'un titre serveur reste à vérifier en direct.

## Cause du SIGSEGV raster confirmée : AmbientBlur

La validation utilisateur dans Kinos normal échoue encore (396490). Son log
mentionne AmbientBlur avant le même SIGSEGV. Ajouter AmbientBlur à la sonde
suffit à reproduire exactement la pile : 398901, thread raster,
libflutter_linux_gtk.so +0x86537a, mêmes appelants. Sans cet effet, la même
sonde avait réussi cinq fois. Le correctif du plugin EGL est nécessaire pour
le crash de libération, mais ne corrige pas ce crash indépendant.

AmbientBlur recopiait une texture vidéo externe avec
RenderRepaintBoundary.toImage ; cette capture n'est pas sûre avec le moteur
actuel. Le widget reçoit désormais la fonction takeScreenshot existante du
lecteur (mpv), décode l'image et conserve son flou et son fondu. Une seconde
vue vidéo cachée et la capture Flutter sont supprimées. Aucun wrapper ni
provider modifié. Les images/codec/picture sont libérés ; la double libération
de l'image partagée au premier fondu est également évitée.

Avant : sonde avec AmbientBlur, SIGSEGV exact. Après : la même sonde avec
capture mpv passe trois fois sur RX 6700 XT (deux XWayland, une Wayland),
PLAYBACK_OK et sortie 0. 850 tests passent, dont trois nouveaux tests sur la
capture, la frame initialement absente et la fermeture en cours de capture.
Analyse : aucune erreur, quatre avertissements et 45 infos.

Le contrôle de pixels sous Xvfb/Mesa logiciel a expiré au démarrage dans ce
dernier passage ; ne pas le déclarer réussi. Les logs sont maintenant inclus
dans l'exception pour diagnostiquer ce cas. La validation finale du parcours
serveur dans l'application normale reste distincte des sondes natives.

Validation utilisateur finale dans Kinos normal, même épisode serveur puis
réduction/réagrandissement : « Ça fonctionne, image correcte ». Le journal
confirme une sortie H/W RX 6700 XT et le passage à la résolution vidéo, sans
nouvelle erreur AmbientBlur. Le crash de lecture est donc résolu sur le
parcours reproduit. Une erreur D-Bus WakelockPlus (service non activable)
reste visible, indépendante du SIGSEGV ; non modifiée dans ce correctif.
