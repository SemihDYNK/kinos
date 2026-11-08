
<h1 align="center">
  <br>
  Kinos
  <br>
</h1>

<h4 align="center">A Jellyfin client for Linux desktop, with an integrated Sonarr/Radarr module.</h4>

<p align="center">
  <a href="#about-this-fork">About this fork</a> •
  <a href="#key-features">Key Features</a> •
  <a href="#building--running">Building &amp; Running</a> •
  <a href="#license">License</a>
</p>

## About this fork

Kinos is a fork of [Fladder](https://github.com/DonutWare/Fladder), a
cross-platform Jellyfin client built with Flutter. It keeps Fladder's
playback engine and general design, narrowed to a single, opinionated
target rather than trying to cover every platform:

* **Linux desktop is the primary target.** Experimental Windows and macOS
  test builds are available through GitHub Actions; mobile, TV and web
  builds are not maintained in this fork.
* **Movies and TV shows only.** Music, Live TV, e-books, photos,
  SyncPlay and remote control are out of scope here.
* **Added:** an integrated Sonarr/Radarr module — library, download
  queue, calendar, and interactive release search — for requesting and
  managing content directly from the client, without switching to the
  *arr web UIs.

See [NOTICE](NOTICE) for the full attribution to the upstream project,
and [LICENSE](LICENSE) for the license text (GPL-3.0-only, unchanged
from upstream — the license covers the code, not the project name,
which is exactly why this fork can be redistributed under its own
identity).

If you're looking for the full cross-platform experience (mobile, TV,
music, Live TV, and more), use [Fladder](https://github.com/DonutWare/Fladder)
directly — this fork intentionally does less.

## Key Features

* Direct, transcode and offline playback
* Media segment skipping (intro/credits, etc.)
* Trickplay support (timeline scrubbing)
* Dark/light mode and multiple color themes
* Keyboard-first navigation, with shortcuts visible in the interface
* Seerr/Jellyseerr integration
* Sonarr/Radarr integration (library, queue, calendar, interactive search)

## Download

Distributable builds are published in
[Releases](https://github.com/SemihDYNK/kinos/releases): the Linux AppImage
(`kinos-linux-x86_64.AppImage`), the Linux tarball, and experimental Windows
and macOS archives, together with `SHA256SUMS.txt`. Linux is the primary
target; the Windows and macOS builds are not signed or notarized. The macOS
archive asks users to reconnect after each app launch because its ad hoc
signature cannot use the Keychain safely.

## Building & Running

This fork primarily targets Linux desktop and is built with
[Flutter](https://flutter.dev/) via [FVM](https://fvm.app/). See
`CLAUDE.md` for the project's technical constraints and conventions.

```sh
fvm flutter pub get
fvm flutter run -d linux
```

For installation, checksums and platform notes, see
[Desktop testing](docs/desktop-testing.md). These builds do not constitute
a signed or notarized public release.

## License

This project is licensed under the GNU General Public License v3.0
only (GPL-3.0-only) — see [LICENSE](LICENSE) for the full text, and
[NOTICE](NOTICE) for the attribution to the upstream Fladder project
this is forked from.
