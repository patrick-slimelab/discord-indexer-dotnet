#!/usr/bin/env bash
set -euo pipefail

# One-step installer for discord-indexer (systemd service on Ubuntu).
#
# What it does:
# - Builds the binary automatically:
#     - prefers local dotnet SDK if present
#     - otherwise uses Docker (build stage) if available
# - Installs binary to /usr/local/bin/discord-indexer
# - Writes secrets to /etc/discord-indexer/indexer.env (0600 root:root)
# - Installs + starts systemd unit discord-indexer.service

# ====== CONFIG (override via env) ======
REPO_DIR="${REPO_DIR:-$(pwd)}"
PROJECT_FILE="${PROJECT_FILE:-$REPO_DIR/discord-indexer.csproj}"
RUNTIME="${RUNTIME:-linux-x64}"
CONFIGURATION="${CONFIGURATION:-Release}"
PUBLISH_DIR="${PUBLISH_DIR:-$REPO_DIR/.publish}"

BIN_DST="${BIN_DST:-/usr/local/bin/discord-indexer}"

SVC_USER="${SVC_USER:-discord-indexer}"
SVC_GROUP="${SVC_GROUP:-discord-indexer}"

STATE_DIR="${STATE_DIR:-/var/lib/discord-indexer}"
LOG_DIR="${LOG_DIR:-/var/log/discord-indexer}"

ENV_DIR="${ENV_DIR:-/etc/discord-indexer}"
ENV_FILE="${ENV_FILE:-$ENV_DIR/indexer.env}"

UNIT_NAME="${UNIT_NAME:-discord-indexer.service}"

# If you want to skip building entirely, set BIN_SRC and SKIP_BUILD=1.
BIN_SRC="${BIN_SRC:-}"

# ====== REQUIRED SETTINGS (export before running) ======
DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN:-}"
DISCORD_GUILD_IDS="${DISCORD_GUILD_IDS:-}"     # optional; if empty, indexer will attempt auto-discovery
MONGODB_URI="${MONGODB_URI:-mongodb://127.0.0.1:27017}"
MONGODB_DB="${MONGODB_DB:-discord_index}"

# Optional CLI flags (if/when your indexer supports them)
INDEXER_OPTS="${INDEXER_OPTS:-}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# ====== checks ======
[[ -f "$PROJECT_FILE" ]] || die "Could not find project file: $PROJECT_FILE (run from repo root)"
[[ -n "$DISCORD_BOT_TOKEN" ]] || die "DISCORD_BOT_TOKEN is required (export it before running)."

# ====== build ======
if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  if [[ -z "$BIN_SRC" ]]; then
    BIN_SRC="$PUBLISH_DIR/discord-indexer"
  fi

  rm -rf "$PUBLISH_DIR" && mkdir -p "$PUBLISH_DIR"

  if need_cmd dotnet; then
    echo "[install] Building with local dotnet SDK -> $PUBLISH_DIR"
    dotnet publish "$PROJECT_FILE" \
      -c "$CONFIGURATION" \
      -r "$RUNTIME" \
      -o "$PUBLISH_DIR" \
      --self-contained true \
      -p:PublishSingleFile=true \
      -p:PublishTrimmed=false
  elif need_cmd docker; then
    # Docker build fallback: uses repo Dockerfile build stage.
    echo "[install] dotnet not found; building via Docker"
    echo "[install] Building docker image (target=export) ..."
    docker build -t discord-indexer-build:local --target export "$REPO_DIR" >/dev/null

    cid="$(docker create discord-indexer-build:local)"
    trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT

    echo "[install] Extracting binary from image -> $BIN_SRC"
    docker cp "$cid:/discord-indexer" "$BIN_SRC"
    chmod +x "$BIN_SRC"
  else
    die "Neither dotnet SDK nor docker is installed, so I can't build the binary. Install dotnet-sdk-8.0 or docker, or set BIN_SRC=/path/to/prebuilt/discord-indexer and SKIP_BUILD=1."
  fi
fi

[[ -n "$BIN_SRC" ]] || die "BIN_SRC is empty (set BIN_SRC or allow the script to build)."
[[ -f "$BIN_SRC" ]] || die "Binary not found at BIN_SRC=$BIN_SRC"

# ====== create user/group ======
if ! getent group "$SVC_GROUP" >/dev/null; then
  sudo groupadd --system "$SVC_GROUP"
fi

if ! id -u "$SVC_USER" >/dev/null 2>&1; then
  sudo useradd --system --gid "$SVC_GROUP" \
    --home-dir "$STATE_DIR" --create-home \
    --shell /usr/sbin/nologin \
    "$SVC_USER"
fi

# ====== dirs ======
sudo install -d -o "$SVC_USER" -g "$SVC_GROUP" -m 0750 "$STATE_DIR"
sudo install -d -o "$SVC_USER" -g "$SVC_GROUP" -m 0750 "$LOG_DIR"
sudo install -d -o root -g root -m 0755 "$ENV_DIR"

# ====== install binary ======
echo "[install] Installing binary -> $BIN_DST"
sudo install -o root -g root -m 0755 "$BIN_SRC" "$BIN_DST"

# ====== write env file (secrets live here) ======
echo "[install] Writing env file -> $ENV_FILE"
tmp_env="$(mktemp)"
cat >"$tmp_env" <<EOF
# discord-indexer env (loaded by systemd)
DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN}
DISCORD_GUILD_IDS=${DISCORD_GUILD_IDS}
MONGODB_URI=${MONGODB_URI}
MONGODB_DB=${MONGODB_DB}

# Optional extra flags consumed by ExecStart via \$INDEXER_OPTS
INDEXER_OPTS=${INDEXER_OPTS}
EOF

sudo install -o root -g root -m 0600 "$tmp_env" "$ENV_FILE"
rm -f "$tmp_env"

# ====== systemd unit ======
echo "[install] Installing systemd unit -> /etc/systemd/system/${UNIT_NAME}"
tmp_unit="$(mktemp)"
cat >"$tmp_unit" <<EOF
[Unit]
Description=Discord Indexer (.NET)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SVC_USER}
Group=${SVC_GROUP}
WorkingDirectory=${STATE_DIR}
EnvironmentFile=${ENV_FILE}

StandardOutput=append:${LOG_DIR}/discord-indexer.log
StandardError=append:${LOG_DIR}/discord-indexer.err

ExecStart=${BIN_DST} \$INDEXER_OPTS
Restart=always
RestartSec=2

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${STATE_DIR} ${LOG_DIR}
LockPersonality=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF

sudo install -o root -g root -m 0644 "$tmp_unit" "/etc/systemd/system/${UNIT_NAME}"
rm -f "$tmp_unit"

# ====== enable + start ======
echo "[install] Enabling + starting ${UNIT_NAME}"
sudo systemctl daemon-reload
sudo systemctl enable --now "${UNIT_NAME}"

echo
echo "OK: Installed and started: ${UNIT_NAME}"
echo "Status: sudo systemctl status ${UNIT_NAME} --no-pager"
echo "Logs:   sudo journalctl -u ${UNIT_NAME} -f"
