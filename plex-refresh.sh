#!/bin/bash

# Plex Library Refresh Script
# Runs on the Plex server. Called remotely via SSH by the Debian LXC trigger script.
# Config: /usr/local/bin/plex-auto-scan/config.conf

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="$SCRIPT_DIR/config.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

source "$CONFIG_FILE"

CATEGORY="${1:-}"

log() {
    echo "[$(date '+%d-%m-%Y %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null
}

log "========================================="
log "plex-refresh.sh started"
log "Category: ${CATEGORY:-'(none)'}"

# Map qBittorrent category (case-insensitive) to Plex section ID
resolve_section() {
    local cat
    cat=$(echo "$1" | tr '[:upper:]' '[:lower:]')

    case "$cat" in
        4kmovie)      echo "$SECTION_4KMOVIE" ;;
        documentary)  echo "$SECTION_DOCUMENTARY" ;;
        movie)        echo "$SECTION_MOVIE" ;;
        standup)      echo "$SECTION_STANDUP" ;;
        tv-show)      echo "$SECTION_TV_SHOW" ;;
        *)            echo "" ;;
    esac
}

if [ -z "$CATEGORY" ]; then
    log "No category provided, using default section: $SECTION_DEFAULT"
    SECTION_ID="$SECTION_DEFAULT"
else
    SECTION_ID=$(resolve_section "$CATEGORY")

    if [ -z "$SECTION_ID" ]; then
        log "WARNING: Unknown category '$CATEGORY', using default section: $SECTION_DEFAULT"
        SECTION_ID="$SECTION_DEFAULT"
    else
        log "Mapped '$CATEGORY' -> section $SECTION_ID"
    fi
fi

# Trigger Plex library scan
SCAN_URL="${PLEX_URL}/library/sections/${SECTION_ID}/refresh?X-Plex-Token=${PLEX_TOKEN}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$SCAN_URL")

if [ "$HTTP_CODE" = "200" ]; then
    log "Scan triggered for section $SECTION_ID (HTTP $HTTP_CODE)"
    exit 0
else
    log "ERROR: Scan failed for section $SECTION_ID (HTTP $HTTP_CODE)"
    exit 1
fi