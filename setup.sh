#!/usr/bin/env bash
#
# setup.sh — reproducible setup for the mini_browser overlay.
#
# What it does:
#   1. Ensures depot_tools is available.
#   2. Fetches the pinned Chromium checkout (if not already present).
#   3. Symlinks our embedder source into the Chromium tree.
#   4. Applies any patches from patches/.
#   5. Copies our build config and runs `gn gen`.
#
# It is intentionally NON-DESTRUCTIVE to an existing checkout: if the Chromium
# source is already present, it will NOT re-fetch or re-sync unless you pass
# FORCE_SYNC=1, so it won't disturb an in-progress or completed build.
#
# Usage:
#   ./setup.sh
#   CHROMIUM_SRC=/path/to/existing/chromium/src ./setup.sh   # reuse an existing checkout
#   FORCE_SYNC=1 ./setup.sh                                   # re-pin/re-sync even if present

set -euo pipefail

# ---- Pinned upstream -------------------------------------------------------
CHROMIUM_REF="cd1d42cba19c64f3386d5dfa1475d620b6efb6a4"   # Chromium 151.0.7897.0
# ---- Project conventions ---------------------------------------------------
EMBEDDER_NAME="mini_browser"
BUILD_DIR="out/Shell"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Where the Chromium checkout lives. Default: self-contained inside the repo
# (git-ignored). Override with CHROMIUM_SRC to reuse an existing checkout.
CHROMIUM_SRC="${CHROMIUM_SRC:-$REPO_ROOT/chromium/src}"
DEPOT_TOOLS="${DEPOT_TOOLS:-$REPO_ROOT/chromium/depot_tools}"
FORCE_SYNC="${FORCE_SYNC:-0}"

echo "==> Repo:         $REPO_ROOT"
echo "==> Chromium src: $CHROMIUM_SRC"
echo "==> Pinned ref:   $CHROMIUM_REF"
echo ""

# ---- 1. depot_tools --------------------------------------------------------
if [ ! -d "$DEPOT_TOOLS" ]; then
  echo "==> Cloning depot_tools into $DEPOT_TOOLS"
  mkdir -p "$(dirname "$DEPOT_TOOLS")"
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS"
fi
export PATH="$PATH:$DEPOT_TOOLS"

# ---- 2. Fetch / pin Chromium ----------------------------------------------
if [ ! -d "$CHROMIUM_SRC" ]; then
  echo "==> No checkout found. Fetching Chromium (this takes a long time)..."
  mkdir -p "$(dirname "$CHROMIUM_SRC")"
  ( cd "$(dirname "$CHROMIUM_SRC")" && caffeinate fetch --no-history chromium )
  echo "==> Pinning to $CHROMIUM_REF"
  # NOTE: with a --no-history (shallow) fetch, pinning to an arbitrary commit may
  # require fetching it explicitly. If this fails, do a full `fetch chromium`.
  ( cd "$CHROMIUM_SRC" \
      && git fetch --depth=1 origin "$CHROMIUM_REF" \
      && git checkout "$CHROMIUM_REF" \
      && gclient sync -D --no-history )
else
  CUR_REF="$(cd "$CHROMIUM_SRC" && git rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "==> Existing checkout found at HEAD=$CUR_REF"
  if [ "$FORCE_SYNC" = "1" ]; then
    echo "==> FORCE_SYNC=1: re-pinning to $CHROMIUM_REF and syncing"
    ( cd "$CHROMIUM_SRC" \
        && git fetch --depth=1 origin "$CHROMIUM_REF" \
        && git checkout "$CHROMIUM_REF" \
        && gclient sync -D --no-history )
  else
    echo "    Skipping fetch/sync to avoid disturbing it. (Pass FORCE_SYNC=1 to re-pin.)"
    [ "$CUR_REF" = "$CHROMIUM_REF" ] || echo "    WARNING: HEAD != pinned ref ($CHROMIUM_REF)."
  fi
fi

# ---- 3. Link our embedder into the tree -----------------------------------
LINK_TARGET="$CHROMIUM_SRC/$EMBEDDER_NAME"
if [ ! -e "$LINK_TARGET" ]; then
  ln -s "$REPO_ROOT/$EMBEDDER_NAME" "$LINK_TARGET"
  echo "==> Linked $EMBEDDER_NAME -> $LINK_TARGET"
else
  echo "==> $EMBEDDER_NAME already present in tree (skipping link)"
fi

# ---- 4. Apply patches ------------------------------------------------------
shopt -s nullglob
PATCHES=("$REPO_ROOT"/patches/*.patch)
if [ ${#PATCHES[@]} -eq 0 ]; then
  echo "==> No patches to apply."
else
  for p in "${PATCHES[@]}"; do
    echo "==> Applying patch: $(basename "$p")"
    ( cd "$CHROMIUM_SRC" && git apply --check "$p" && git apply "$p" )
  done
fi

# ---- 5. Build configuration ------------------------------------------------
mkdir -p "$CHROMIUM_SRC/$BUILD_DIR"
cp "$REPO_ROOT/build/args.gn" "$CHROMIUM_SRC/$BUILD_DIR/args.gn"
echo "==> Wrote build/args.gn -> $CHROMIUM_SRC/$BUILD_DIR/args.gn"
( cd "$CHROMIUM_SRC" && gn gen "$BUILD_DIR" )

# ---- Done ------------------------------------------------------------------
cat <<EOF

==> Setup complete.

To build (cap parallelism to -j 2 on low-RAM machines — see docs/building.md):

    cd "$CHROMIUM_SRC"
    caffeinate autoninja -C $BUILD_DIR content_shell -j 2

To run:

    "$CHROMIUM_SRC/$BUILD_DIR/Content Shell.app/Contents/MacOS/Content Shell" \\
      --use-mock-keychain --disable-features=DialMediaRouteProvider https://example.com
EOF
