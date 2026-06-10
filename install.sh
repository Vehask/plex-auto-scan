#!/bin/bash

# Install / Update script for Plex Auto Scan
# Run as root.
#
# First install:  sudo bash install.sh
# Update scripts: sudo bash install.sh
# Update config:  sudo bash install.sh --update-config

set -e

INSTALL_DIR="/usr/local/bin/plex-auto-scan"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/plex-refresh.log"
UPDATE_CONFIG=false

for arg in "$@"; do
    [ "$arg" = "--update-config" ] && UPDATE_CONFIG=true
done

# --- Helpers ---

ok()   { echo "  [OK]  $1"; }
info() { echo "  [--]  $1"; }
warn() { echo "  [!!]  $1"; }
err()  { echo "  [ERR] $1"; exit 1; }

# --- Checks ---

if [ "$EUID" -ne 0 ]; then
    err "This script must be run as root (sudo bash install.sh)"
fi

echo ""
echo "=== Plex Auto Scan - Plex Server Install/Update ==="
echo "    Install directory : $INSTALL_DIR"
echo "    Source directory  : $SCRIPT_DIR"
echo "    Update config     : $UPDATE_CONFIG"
echo ""

# --- Install directory ---

if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    ok "Created $INSTALL_DIR"
else
    info "Directory exists: $INSTALL_DIR"
fi

# --- Install / update scripts ---

install_script() {
    local name="$1"
    local src="$SCRIPT_DIR/$name"
    local dst="$INSTALL_DIR/$name"

    if [ ! -f "$src" ]; then
        warn "Not found in source, skipping: $name"
        return
    fi

    cp "$src" "$dst"
    chmod +x "$dst"
    ok "Installed: $dst"
}

install_script "plex-refresh.sh"
install_script "get-plex-info.sh"

# --- Config file ---

CONFIG_SRC="$SCRIPT_DIR/config.conf"
CONFIG_DST="$INSTALL_DIR/config.conf"

if [ ! -f "$CONFIG_SRC" ]; then
    err "config.conf not found in $SCRIPT_DIR"
fi

if [ -f "$CONFIG_DST" ] && [ "$UPDATE_CONFIG" = false ]; then
    info "Config already installed, preserving: $CONFIG_DST"
    info "(run with --update-config to overwrite)"
else
    cp "$CONFIG_SRC" "$CONFIG_DST"
    if [ "$UPDATE_CONFIG" = true ]; then
        ok "Updated config: $CONFIG_DST"
    else
        ok "Installed config: $CONFIG_DST"
    fi
fi

# --- Log file ---

if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 666 "$LOG_FILE"
    ok "Created log: $LOG_FILE"
else
    info "Log exists: $LOG_FILE"
fi

# --- Done ---

echo ""
echo "=== Done ==="
echo ""
echo "Steps to complete setup:"
echo "  1. Edit config      : nano $INSTALL_DIR/config.conf"
echo "     - Set PLEX_TOKEN (run get-plex-info.sh if you need to find it)"
echo "     - Set section IDs to match your Plex libraries"
echo "  2. Find section IDs : bash $INSTALL_DIR/get-plex-info.sh"
echo "  3. Test manually    : bash $INSTALL_DIR/plex-refresh.sh Movie"
echo "  4. Check log        : tail -f $LOG_FILE"
echo ""
echo "Plex section IDs for reference:"
echo "  http://localhost:32400/library/sections/?X-Plex-Token=\$(grep PLEX_TOKEN $INSTALL_DIR/config.conf | cut -d'\"' -f2)"
echo ""