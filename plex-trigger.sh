#!/bin/bash

# Plex Library Scan Trigger
# Called by qBittorrent when a download completes.
# In qBittorrent: Options > Downloads > "Run external program on torrent completion"
#   Command: /path/to/plex-trigger.sh "%L"
#
# Required config settings (in /usr/local/bin/plex-auto-scan/config.conf):
#   SSH_USER     - SSH user on the Plex server
#   SSH_HOST     - IP/hostname of the Plex server
#   SSH_PORT     - SSH port (default: 22)
#   SSH_KEY      - Path to SSH private key for passwordless auth
#   REMOTE_SCRIPT - Path to plex-refresh.sh on the Plex server
#   LOG_FILE     - Path to log file

CONFIG_FILE="/usr/local/bin/plex-auto-scan/config.conf"

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
log "Trigger started"
log "Category  : ${CATEGORY:-'(none)'}"
log "Target    : $SSH_USER@$SSH_HOST:$SSH_PORT"
log "Script    : $REMOTE_SCRIPT"

if [ -n "$CATEGORY" ]; then
    REMOTE_CMD="'$REMOTE_SCRIPT' '$CATEGORY'"
else
    REMOTE_CMD="'$REMOTE_SCRIPT'"
fi

ssh -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -i "$SSH_KEY" \
    -p "$SSH_PORT" \
    "$SSH_USER@$SSH_HOST" \
    "nohup $REMOTE_CMD >/dev/null 2>&1 &" >> "$LOG_FILE" 2>&1

EXIT_CODE=$?
log "SSH exit code: $EXIT_CODE"
exit $EXIT_CODE