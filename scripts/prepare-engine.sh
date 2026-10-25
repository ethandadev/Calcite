#!/usr/bin/env bash
# Fetch the Amethyst-iOS engine at the pinned commit and apply Calcite's patches.
# Usage: scripts/prepare-engine.sh [upstream-url]   -> creates ./Engine
set -euo pipefail
cd "$(dirname "$0")/.."
URL="${1:-https://github.com/AngelAuraMC/Amethyst-iOS}"
REF="$(tr -d '[:space:]' < engine/UPSTREAM_REF)"
rm -rf Engine
git init -q Engine
git -C Engine remote add origin "$URL"
git -C Engine fetch -q --depth 1 origin "$REF"
git -C Engine checkout -q FETCH_HEAD
git -C Engine submodule update --init --recursive --depth 1
for p in engine/patches/*.patch; do
  echo "Applying $p"
  git -C Engine apply --whitespace=nowarn "$PWD/$p"
done
echo "Engine ready at ./Engine ($REF + patches)"
