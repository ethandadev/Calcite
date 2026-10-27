# Calcite

A Minecraft: Java Edition launcher for iPhone and iPad, built as a full replacement
for Amethyst-iOS. Sideload the unsigned IPA with SideStore.

**Status:** v0.15 beta. New navigation and onboarding, built-in JIT, mod/skin/instance tools, Java 25 and a Minecraft 26.3 rendering stack are in; JIT, pairing and 26.3 are still being verified on real devices.

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

## What Calcite adds on top of Amethyst
- Redesigned app: floating tab bar (Play, Library, Discover, Tools, Settings), a Home screen with a stretchy hero card,
  card-based hubs, tap-to-select instances, spring animations and haptics throughout, and an animated welcome tour
  (replay it from Home or Tools)
- Minecraft 26.3 stack: LWJGL 3.4.3 with SDL3 windowing/input and Vulkan through MoltenVK 1.4.2, kept separate from the
  older stack so 1.x versions are unaffected (see `scripts/fetch-stack341.sh`)
- Java 25 / automatic Java selection fix (Minecraft 26.x works)
- Compact on-screen keyboard (Settings > Controls > Compact keyboard)
- Control layouts: Minimal, Combat, Builder, Left-handed, PvP, Survival, Redstone, Parkour, Left Combat (pick per profile)
- Crash explainer: plain-English cause after a bad session
- Automatic world backups (zips to `backups/`, keeps the newest 3 per world) and a Restore World menu item
- Performance Pack: one tap installs Sodium, Lithium, FerriteCore and friends for Fabric profiles
- Mod Browser: search Modrinth, install with required dependencies, enable/disable/delete installed mods
- Skin Manager: upload or reset your skin (Microsoft accounts)
- Clone profiles: swipe right on a profile to copy it with its own game folder
- Built-in JIT (beta) with on-device pairing on iOS 27: see `docs/JIT.md`

## Install
1. Download `Calcite.ipa` from the latest [Release](../../releases/latest) and open it in SideStore.
2. Or add `https://raw.githubusercontent.com/ethandadev/Calcite/main/source.json` as a SideStore source for updates.
3. Enable JIT with the built-in JIT (see `docs/JIT.md`) or with StikDebug.
