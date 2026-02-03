#!/usr/bin/env bash
set -euo pipefail

# install-discord-indexer-from-release.sh
#
# Installs discord-indexer + discord-indexer-search from the latest GitHub Release.
# Designed for Ubuntu hosts (e.g. "mystery"). Does NOT require dotnet or docker.
#
# What it does:
# - Downloads discord-indexer-linux-x64.tar.gz + .sha256 from a GitHub Release
# - Verifies checksums
# - Installs binaries to /usr/local/bin
# - Optionally (default) installs/updates systemd unit + env file (compatible with existing service installer)
#
# Env vars:
#   REPO=patrick-slimelab/discord-indexer-dotnet   (default)
#   VERSION=latest|vX.Y.Z                          (default: latest)
#   INSTALL_SYSTEMD=1|0                            (default: 1)
#
# After install:
#   sudo systemctl daemon-reload
#   sudo systemctl restart discord-indexer.service

REPO="${REPO:-patrick-slimelab/discord-indexer-dotnet}"
VERSION="${VERSION:-latest}"
INSTALL_SYSTEMD="${INSTALL_SYSTEMD:-1}"

ASSET_TGZ="discord-indexer-linux-x64.tar.gz"
ASSET_SHA="discord-indexer-linux-x64.sha256"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

need curl
need tar
need sha256sum

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: run as root (use sudo)" >&2
  exit 1
fi

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# Resolve tag
TAG="$VERSION"
if [[ "$VERSION" == "latest" ]]; then
  echo "[install] Resolving latest release for $REPO"
  TAG="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | sed -n 's/.*"tag_name" *: *"\([^"]*\)".*/\1/p' | head -n1)"
  if [[ -z "$TAG" ]]; then
    echo "ERROR: could not resolve latest release tag via GitHub API" >&2
    exit 1
  fi
fi

BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"

echo "[install] Downloading $ASSET_TGZ and $ASSET_SHA from $BASE_URL"

curl -fsSL -o "$TMP/$ASSET_TGZ" "$BASE_URL/$ASSET_TGZ"
curl -fsSL -o "$TMP/$ASSET_SHA" "$BASE_URL/$ASSET_SHA"

cd "$TMP"

echo "[install] Extracting"
tar -xzf "$ASSET_TGZ"

echo "[install] Verifying checksums"
sha256sum -c "$ASSET_SHA"

install -m 0755 "$TMP/discord-indexer" /usr/local/bin/discord-indexer
install -m 0755 "$TMP/discord-indexer-search" /usr/local/bin/discord-indexer-search

echo "[install] Installed:" \
  "/usr/local/bin/discord-indexer" \
  "/usr/local/bin/discord-indexer-search"

if [[ "$INSTALL_SYSTEMD" == "1" ]]; then
  echo "[install] Installing/updating systemd service + env file (via existing installer)"
  # Reuse the existing host installer for unit + mongo-container setup.
  # It will overwrite the binary, but that's OK (same version).
  # If you want systemd only without docker-mongo, we can add a separate unit-only path.
  if [[ -f "/etc/discord-indexer/indexer.env" ]]; then
    echo "[install] Found existing /etc/discord-indexer/indexer.env (keeping)"
  fi

  if [[ -x "./install-discord-indexer-service.sh" ]]; then
    # When running from repo checkout
    ./install-discord-indexer-service.sh
  else
    echo "[install] NOTE: systemd installer script not present in this temp dir."
    echo "[install] If you want systemd managed service, run the repo installer:" >&2
    echo "         sudo -E ./install-discord-indexer-service.sh" >&2
  fi
fi

echo "[install] Done. If using systemd:" \
  "sudo systemctl daemon-reload && sudo systemctl restart discord-indexer.service"
