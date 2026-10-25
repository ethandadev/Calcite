# Calcite

A native SwiftUI Minecraft: Java Edition launcher for iPhone and iPad, built as a full replacement
for Amethyst-iOS. Sideload the unsigned IPA with SideStore.

**Status:** v1.0 in progress (Phase 0: build pipeline, Phase 1: Java 25 + automatic Java selection, Phase 2: built-in JIT).

## Build
- `swift test` runs the core logic tests (needs macOS, or the CI job).
- The **Build IPA** workflow produces an unsigned `Calcite.ipa` artifact. Open Actions, run it, download, sideload.

## License
AGPL-3.0 (see CREDITS.md). The LICENSE file is added from GitHub's license picker.
