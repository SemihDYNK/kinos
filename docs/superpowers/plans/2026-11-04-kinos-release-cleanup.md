# Kinos Release Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a clean, reproducible desktop release candidate for Kinos without broadening its supported feature scope.

**Architecture:** Keep the current desktop-test workflow as the build authority. Move Kinos-owned visible copy through Flutter localization with English as the fallback and French as the complete product language. A tag-triggered release workflow packages the existing Windows portable archive and universal macOS archive, including source and license traceability.

**Tech Stack:** Flutter/FVM, Flutter l10n ARB files, GitHub Actions, GitHub Releases.

**Spec:** `AGENTS.md` and `docs/desktop-testing.md`.

## Global Constraints

- Films and series only; do not re-enable music, Live TV, books, photos, SyncPlay or remote control.
- Linux remains the primary target; Windows and macOS are experimental test builds until their real-device checks pass.
- Retain GPL-3.0-only licensing, upstream attribution and bundled font licences in every archive.
- Keep secrets in secure storage; no credentials in assets, logs, source or release notes.
- Use `lib/wrappers/players/lib_mpv.dart` on Linux with `gpu-next`; do not add an HDR path.

## Review Focus

- Missing ARB values fall back to English without crashing locale generation.
- A release archive contains `LICENSE`, `NOTICE`, `BUILD.txt` and the matching source revision.
- A failed AniList/Seerr request cannot block playback, navigation or a manual watched-state update.
- The Windows archive remains portable after extraction and macOS launches on both arm64 and x86_64.
- The version, git tag and release notes all describe the same commit.

---

### Task 1: Complete the French template locale

**Files:**
- Modify: `lib/l10n/app_fr.arb`
- Test: Flutter localization generation and a template-key comparison

**Interfaces:**
- Consumes: `BuildContext.localized` from `lib/util/localization_helper.dart`
- Produces: localizable labels with English fallback and French copy

- [ ] Compare `app_en.arb` and `app_fr.arb` for missing template keys.
- [ ] Add the nine missing French template values, including the `stopSelection` placeholder metadata.
- [ ] Run `flutter gen-l10n`, the affected widget tests and `flutter analyze`.
- [ ] Commit with `fix: complete French template locale`.

### Task 2: Align release documentation and attribution

**Files:**
- Modify: `README.md`
- Modify: `NOTICE`
- Modify: `docs/desktop-testing.md`
- Test: `test/assets/font_licenses_test.dart` and a small documentation/archive assertion if packaging paths change

**Interfaces:**
- Consumes: current desktop artifact names from `.github/workflows/desktop-test.yml`
- Produces: a single documented installation and support path for Linux, Windows and macOS test builds

- [ ] Re-read all attribution, upstream, font and AniList notices against the files actually bundled by CI.
- [ ] Remove stale distribution wording and document only supported installation, verification and rollback steps.
- [ ] Ensure the README points to the source revision and exact desktop test instructions.
- [ ] Run the licence test and verify all referenced files exist.
- [ ] Commit with `docs: prepare Kinos desktop distribution`.

### Task 3: Create a release-candidate pipeline

**Files:**
- Modify: `pubspec.yaml`
- Modify: `.github/workflows/desktop-test.yml` or create `.github/workflows/release.yml`
- Modify: `docs/desktop-testing.md`
- Modify: Windows and macOS native application icons
- Test: workflow YAML validation, package-content assertions and CI artifacts on a release-candidate tag

**Interfaces:**
- Consumes: Windows `Release/` bundle and macOS `kinos-macos-universal.zip`
- Produces: versioned `Kinos` Windows and macOS assets, checksums and source link on one GitHub Release

- [ ] Choose the target version after checking existing origin tags; do not reuse an existing tag.
- [ ] Replace the legacy Fladder Windows and macOS application icons with the committed Kinos brand asset.
- [ ] Add a tag-only release job that uploads the already-validated desktop packages and SHA-256 checksums.
- [ ] Preserve the 14-day Actions artifacts for debugging; Releases are the stable download path.
- [ ] Run the workflow from a release-candidate tag and verify archive content, architecture and signature checks.
- [ ] Commit with `ci: publish Kinos desktop release assets`.

### Task 4: Final validation and publication decision

**Files:**
- Modify: release notes only after validation
- Test: full `flutter analyze`, full `flutter test`, CI checks, and manual Linux/Windows/macOS smoke tests

**Interfaces:**
- Consumes: the tagged release candidate and user testing feedback
- Produces: a publishable release or a documented list of remaining blockers

- [ ] Run full static analysis and the full test suite on the tagged commit.
- [ ] Confirm CI builds Linux checks, Windows portable archive, macOS universal archive and macOS launch test.
- [ ] Perform the documented smoke test: login, navigation, playback, player resize/full-screen, Seerr, AniList and Letterboxd.
- [ ] Decide whether the repository/release stays private for invited testers or becomes public; publish only after this decision.
- [ ] Tag and publish the final release, then commit any release notes generated by the pipeline.

## Self-review

- Scope covers the explicit final-distribution checklist: translations, NOTICE, build reproducibility, validation and publication.
- No product feature is added; AniList, Letterboxd, Seerr and playback are verification targets only.
- Public versus private distribution remains an explicit decision because it affects tester access and GPL source availability.
