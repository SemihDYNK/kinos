# Kinos page transitions — Implementation Plan

**Goal:** Implement the approved navigation motion: ordered top tabs, artwork continuity into details, reversible return with scroll and focus retained.
**Architecture:** Flutter route transitions plus stable, per-card Hero identities. Seed detail screens synchronously; keep data fetching in their existing providers. Animate only opacity and transforms, outside persistent chrome.
**Tech Stack:** Flutter, auto_route, Riverpod; no new dependency.
**Spec:** User-approved recap in this conversation, 28 October 2026.

## Constraints
- Existing theme tokens; keyboard and reduced-motion navigation immediate.
- Sidebar fixed, topbar horizontally centered.
- No data layer restructuring; preserve callbacks and context menus.
- Preserve existing uncommitted work. Final profile rebuild only once.

## Tasks
- [x] Add targeted tests for interrupted page motion, disabled motion and stable artwork identities.
- [x] Add shared artwork navigation and reversible route transition; use seeded detail content immediately.
- [x] Wire carousel, home tiles, library posters and episode cards.
- [x] Animate catalog scope changes in tab order; preserve each scroll position.
- [x] Run targeted and related tests, analysis, review, profile build and launch.

## Review focus
Rapid repeated navigation; duplicate media on one page; missing artwork; slow detail responses; return after source disposal.

## Verification
64 related tests plus the additional interrupted-flight case and the real carousel/detail round trip pass (66 distinct tests). Profile build succeeds. Targeted analysis reports one pre-existing prefer_const_constructors info in app_theme.dart:687, no errors. Native transition smoothness remains to be assessed on the server-backed app.
