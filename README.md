# Calcite

A native SwiftUI Minecraft: Java Edition launcher for iPhone and iPad, built as a full replacement
for Amethyst-iOS. Sideload the unsigned IPA with SideStore.

**Status:** v1.0 in progress (Phase 0: build pipeline, Phase 1: Java 25 + automatic Java selection, Phase 2: built-in JIT).

## Build
- `swift test` runs the core logic tests (needs macOS, or the CI job).
- The **Build IPA** workflow produces an unsigned `Calcite.ipa` artifact. Open Actions, run it, download, sideload.

## License
LGPL-3.0 for the Amethyst-derived engine (see LICENSE); Calcite-original code may be AGPL-3.0 (see CREDITS.md).

## Engine
Calcite is a hard fork of Amethyst-iOS (LGPL-3.0), imported at upstream commit `f98c413` and now owned here, so it
can change freely without tracking upstream. The original README is in `docs/AMETHYST_README.md`.
MobileGlues stays a git submodule (large, unmodified); the small libraries are vendored.

Changes so far:
- Java selection fix for Minecraft 26.x: Java 25 was missing from the default runtime list and the selector silently
  kept Java 17. It now merges bundled runtimes and never picks an older Java.

## Install
1. Download `Calcite.ipa` from the latest [Release](../../releases/latest) and open it in SideStore.
2. Or add `https://raw.githubusercontent.com/ethandadev/Calcite/main/source.json` as a SideStore source for updates.
3. Enable JIT with StikDebug (built-in JIT is in progress).
