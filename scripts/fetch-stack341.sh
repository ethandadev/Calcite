#!/bin/bash
# Assembles the native half of Calcite's "LWJGL 3.4" stack (Minecraft 26.3+) into
# Natives/resources/Frameworks341:
#   - LWJGL 3.4.3 natives for iOS arm64 and a patched SDL3 (prebuilt, FlameLauncher-SDL3 releases)
#   - MoltenVK 1.4.2 (official release; 26.3's shaders need its newer SPIRV-Cross)
#   - SPIRV-Cross C library and shaderc (built from source by FlameLauncher-SDL3's scripts,
#     because LWJGL 3.4.3 needs entry points older prebuilt copies lack)
#
# Needs macOS with Xcode, cmake, ninja, python3, curl.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Natives/resources/Frameworks341"
BASE="https://github.com/FlameLaunchers/FlameLauncher-SDL3"
LWJGL_TAG="${LWJGL_TAG:-lwjgl-v3.4.3-1}"
SDL_TAG="${SDL_TAG:-sdl3-v3.4.16-3}"
MVK_VERSION="v1.4.2"
MVK_SHA256="b5d947b1660e6e9fed40b9cd2387e160aaab9e80b775c0cef7e14059405178c1"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
rm -rf "$OUT"; mkdir -p "$OUT"

echo "== LWJGL natives ($LWJGL_TAG)"
curl -fsSL --retry 3 "$BASE/releases/download/$LWJGL_TAG/lwjgl-ios-arm64.zip" -o "$WORK/lwjgl.zip"
unzip -oq "$WORK/lwjgl.zip" -d "$OUT"

echo "== SDL3 ($SDL_TAG)"
curl -fsSL --retry 3 "$BASE/releases/download/$SDL_TAG/libSDL3-ios-arm64.dylib" -o "$OUT/libSDL3.dylib"

echo "== MoltenVK $MVK_VERSION"
curl -fsSL --retry 3 "https://github.com/KhronosGroup/MoltenVK/releases/download/$MVK_VERSION/MoltenVK-ios.tar" -o "$WORK/mvk.tar"
echo "$MVK_SHA256  $WORK/mvk.tar" | shasum -a 256 -c --status
MVK_BIN="MoltenVK/MoltenVK/dynamic/MoltenVK.xcframework/ios-arm64/MoltenVK.framework/MoltenVK"
tar -xf "$WORK/mvk.tar" -C "$WORK" "$MVK_BIN"
cp "$WORK/$MVK_BIN" "$OUT/libMoltenVK.dylib"
# The app already ships an older MoltenVK (1.2.9). dyld treats two images with the same install
# name as one, so give this copy its own identity or the old one silently wins.
install_name_tool -id @rpath/CalciteMoltenVK142.dylib "$OUT/libMoltenVK.dylib"
strings "$OUT/libMoltenVK.dylib" | grep -m1 -E '^1\.4\.' || true

echo "== SPIRV-Cross and shaderc (built from source)"
git clone --depth 1 "$BASE" "$WORK/flame"
( cd "$WORK/flame" && ./Scripts/build-spirv-cross.sh && ./Scripts/build-shaderc.sh )
cp "$WORK/flame/Runtime/Frameworks/libspirv-cross.dylib" "$OUT/"
cp "$WORK/flame/Runtime/Frameworks/libshaderc.dylib" "$OUT/"

echo "== Result"
ls -la "$OUT"
for f in "$OUT"/*.dylib; do
  lipo -info "$f" | grep -q arm64 || { echo "not arm64: $f"; exit 1; }
done
