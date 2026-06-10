# Plex Auto Scan

Automatically trigger Plex library scans when qBittorrent downloads complete. Uses SSH to bridge your torrent box and Plex server — no agents, no middleware, no cloud dependencies.

## Architecture

```
qBittorrent (torrent box)
    │
    │ Torrent completes → calls plex-trigger.sh "%L"
    ▼
plex-trigger.sh
    │
    │ SSHes into Plex server with category name
    ▼
plex-refresh.sh (on Plex server)
    │
    │ Maps category → Plex section ID via config.conf
    ▼
Plex API → Library scan triggered
```

## Files

| File | Where it runs | Purpose |
|------|---------------|---------|
| `plex-trigger.sh` | **qBittorrent host** | Called by qBittorrent on torrent completion. SSHes to the Plex server and invokes `plex-refresh.sh`. |
| `plex-refresh.sh` | **Plex server** | Maps qBittorrent categories to Plex section IDs and triggers a library scan via the Plex API. |
| `get-plex-info.sh` | **Plex server** | Helper to find your Plex token and list library section IDs. |
| `install.sh` | **Plex server** | Installs/updates all scripts to `/usr/local/bin/plex-auto-scan/`. |
| `config.conf` | **Both** | Shared configuration — Plex token, section IDs, SSH settings, log path. |

## Prerequisites

- **qBittorrent host**: Linux with SSH client, bash
- **Plex server**: Linux with `curl`, bash, SSH server running
- SSH key-based authentication from qBittorrent host → Plex server (no password prompt)

## Setup

### 1. Clone or copy the scripts to your qBittorrent host

```bash
git clone https://github.com/Vehask/plex-auto-scan.git /opt/plex-auto-scan
```

Or copy the files manually to `/usr/local/bin/scripts/` or wherever you prefer.

### 2. Install on the Plex server

SSH into your Plex server and run:

```bash
# Copy scripts to Plex server (run from qBittorrent host)
scp -r /opt/plex-auto-scan root@YOUR_PLEX_IP:/tmp/plex-auto-scan

# On the Plex server
sudo bash /tmp/plex-auto-scan/install.sh
```

### 3. Configure

Edit the config file on the Plex server (and copy it to the qBittorrent host):

```bash
sudo nano /usr/local/bin/plex-auto-scan/config.conf
```

#### Find your Plex token and section IDs

On the Plex server:

```bash
sudo bash /usr/local/bin/plex-auto-scan/get-plex-info.sh
```

Or manually:

```bash
# List library sections
curl "http://localhost:32400/library/sections/?X-Plex-Token=YOUR_PLEX_TOKEN"
```

#### Config file example

```ini
# Plex connection
PLEX_TOKEN="YOUR_PLEX_TOKEN_HERE"
PLEX_URL="http://localhost:32400"

# SSH (for plex-trigger.sh on the qBittorrent host)
SSH_USER="root"
SSH_HOST="192.168.1.100"
SSH_PORT="22"
SSH_KEY="/root/.ssh/plex_server_key"
REMOTE_SCRIPT="/usr/local/bin/plex-auto-scan/plex-refresh.sh"

# Logging
LOG_FILE="/var/log/plex-refresh.log"

# Category → Section ID mappings
SECTION_4KMOVIE="3"
SECTION_DOCUMENTARY="4"
SECTION_MOVIE="2"
SECTION_STANDUP="5"
SECTION_TV_SHOW="1"
SECTION_DEFAULT="1"
```

### 4. Configure qBittorrent

In **qBittorrent → Options → Downloads**:

Set **"Run external program on torrent completion"** to:

```
/path/to/plex-trigger.sh "%L"
```

Where `%L` passes the torrent's category label.

### 5. Set up SSH key authentication

On your qBittorrent host, generate a key pair and install it on the Plex server:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/plex_server_key -N ""
ssh-copy-id -i ~/.ssh/plex_server_key root@YOUR_PLEX_IP
```

Test it:

```bash
ssh -i ~/.ssh/plex_server_key -o BatchMode=yes root@YOUR_PLEX_IP "echo OK"
```

### 6. Test the setup

On the qBittorrent host:

```bash
# Test with a specific category
/usr/local/bin/scripts/plex-trigger.sh movie

# Check the log on the Plex server
ssh root@YOUR_PLEX_IP "tail -f /var/log/plex-refresh.log"
```

## How the category mapping works

| qBittorrent category | Plex section ID variable | Purpose |
|----------------------|--------------------------|---------|
| `4kmovie` | `SECTION_4KMOVIE` | 4K Movies |
| `documentary` | `SECTION_DOCUMENTARY` | Documentaries |
| `movie` | `SECTION_MOVIE` | Movies |
| `standup` | `SECTION_STANDUP` | Standup Comedy |
| `tv-show` | `SECTION_TV_SHOW` | TV Shows |

Unrecognized categories fall back to `SECTION_DEFAULT`.

## Security notes

- The Plex token grants full API access to your Plex server — treat it like a password
- SSH key-based authentication avoids storing passwords in config files
- The log file may contain token references in debug output — set appropriate permissions
- Consider restricting SSH access to specific IP addresses on the Plex server

## Troubleshooting

**"Config file not found"** → Ensure config.conf exists at the expected path. The trigger script looks for it at `/usr/local/bin/plex-auto-scan/config.conf`.

**SSH connection failed** → Verify SSH key authentication works with `ssh -i <key> -o BatchMode=yes user@host`.

**HTTP 401 from Plex** → Your Plex token is invalid or expired. Run `get-plex-info.sh` to get a fresh one.

**HTTP 404 from Plex** → The section ID doesn't match any Plex library. List available sections:

```bash
curl "http://localhost:32400/library/sections/?X-Plex-Token=YOUR_TOKEN"
```

## License

MIT