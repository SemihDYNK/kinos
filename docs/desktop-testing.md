# Versions distribuables Kinos : Linux, Windows et macOS

Linux reste la plateforme principale. Les builds Windows et macOS sont
expérimentaux : une compilation réussie ne garantit pas encore la lecture
vidéo ou la fluidité sur chaque machine. Les comptes et réglages restent
locaux à chaque installation ; aucun identifiant n’est inclus dans les archives.

## Télécharger

Les versions durables sont dans les **Releases** du dépôt GitHub Kinos.
Chaque release publie aussi les artefacts de l’exécution **Kinos desktop tests**
correspondante :

- `kinos-linux-x86_64.AppImage` : Linux 64 bits, archive exécutable.
- `kinos-linux-x86_64.tar.gz` : Linux 64 bits, archive à extraire.
- `kinos-windows-x64-portable` : Windows 64 bits Intel/AMD.
- `kinos-macos-universal` : Mac Apple Silicon et Intel.
- `SHA256SUMS.txt` : empreintes SHA-256 des archives.

Les artefacts Actions expirent après 14 jours ; la Release reste la référence.
Le workflow s’exécute sur les pushes de `main`, la branche de préparation
`codex/desktop-test-builds` et les PR vers `main`. Une fois présent sur `main`,
il peut aussi être relancé avec **Run workflow**. Laisser `macos_artifact_run`
vide pour recompiler. Pour diagnostiquer le lancement d’une archive existante,
saisir son ID d’exécution : seul le test Mac est relancé, sans changer le binaire.

Une poussée du tag `vX.Y.Z` lance les mêmes vérifications, puis crée une
**GitHub Release** avec les archives Linux, Windows, macOS et
`SHA256SUMS.txt`. Le workflow ne crée jamais le tag lui-même et ne publie rien
sur les stores. Tant que le dépôt reste privé, seuls ses collaborateurs peuvent
télécharger la release.

## Linux

Télécharger `kinos-linux-x86_64.AppImage`, puis :

```sh
chmod +x kinos-linux-x86_64.AppImage
./kinos-linux-x86_64.AppImage
```

Si FUSE 2 n’est pas disponible sur la distribution, lancer directement :

```sh
./kinos-linux-x86_64.AppImage --appimage-extract-and-run
```

L’archive `kinos-linux-x86_64.tar.gz` reste disponible pour les systèmes où
l’AppImage ne convient pas : extraire le dossier, puis lancer
`bundle/kinos`. Vérifier `SHA256SUMS.txt` avant la première ouverture.

## Windows

Extraire **tout** le ZIP dans un dossier, puis lancer `kinos.exe`.
Les DLL et le dossier `data` doivent rester à côté de l’exécutable.
La version n’est pas signée : Windows peut afficher une demande de
confirmation. Vérifier l’origine et le commit dans `BUILD.txt` avant ouverture.

Si Windows indique que `VCRUNTIME140.dll` ou `MSVCP140.dll` manque, installer
le [Microsoft Visual C++ Redistributable x64](https://aka.ms/vs/17/release/vc_redist.x64.exe),
puis relancer Kinos.

## Mac

Extraire l’artefact, puis `kinos-macos-universal.zip`, et copier `Kinos.app`
dans Applications. Cette version utilise une signature locale ad hoc : elle
n’est ni signée avec un certificat Developer ID ni notariée par Apple. Elle
n’est pas sandboxée, car une archive ad hoc ne peut pas obtenir l’autorisation
Apple nécessaire au trousseau dans le sandbox. Les identifiants restent dans le
trousseau de connexion macOS ; macOS peut demander l’accès au trousseau.

Si macOS bloque l’ouverture, tenter de lancer l’app puis ouvrir
**Réglages Système → Confidentialité et sécurité → Ouvrir quand même**,
après vérification de l’origine de l’archive. Ne pas désactiver Gatekeeper
pour l’ensemble du système.

## Vérification sur les vrais appareils

Tester la connexion Jellyfin, la navigation et le défilement, puis la lecture
d’un film et d’un épisode : son, sous-titres, recherche dans la vidéo,
réduction/réouverture du lecteur et plein écran. Fermer puis rouvrir l’app
pour vérifier la conservation des comptes. Si utilisés, vérifier aussi Seerr,
Arr, AniList et l’import Letterboxd avec un fichier choisi sur cet appareil.

Pour signaler un problème, joindre le commit de `BUILD.txt`, la version du
système, le type de Mac ou GPU Windows et les étapes de reproduction.
Ne pas joindre de jeton, mot de passe ou URL contenant des identifiants.

## Compiler localement

Utiliser la version Flutter indiquée dans `.fvmrc`, avec les outils de
compilation natifs : GTK 3, libmpv, libsecret, ninja et patchelf sur Linux ;
Visual Studio avec la charge C++ sur Windows ; Xcode et CocoaPods sur Mac.
Les fichiers générés Dart nécessaires sont suivis dans Git ; les traductions
sont générées par Flutter.

```sh
fvm flutter pub get --enforce-lockfile
# Linux (plateforme principale) :
fvm flutter build linux --release --no-pub
# Windows :
fvm flutter build windows --release --no-pub
# Sur Mac, à la place de la commande Windows :
fvm flutter build macos --release --no-pub --flavor production
```

L’AppImage Linux de release est produite par le job `linux` à partir de
`AppImageBuilder.yml` ; le workflow corrige le RPATH, inclut `LICENSE` et
`NOTICE`, puis valide le contenu de l’AppImage avant publication.

Le workflow vérifie les architectures et la signature locale du bundle Mac.
Il extrait aussi le ZIP sur macOS 26, vérifie qu’il n’annonce ni sandbox ni
groupe Keychain provisionné, puis confirme que le processus reste actif pendant
15 secondes. Cela couvre le refus de lancement avant le rendu Flutter, sans
remplacer les tests de connexion et de lecture sur un vrai appareil.
Il inclut `LICENSE`, `NOTICE` et la référence exacte du code source dans chaque
archive. La signature de distribution, la notarisation et les installateurs
restent réservés à la version distribuable finale.
