#!/usr/bin/env bash
set -euo pipefail

# Refresh SSH known_hosts entries for GNS3 OOB-managed nodes.
#
# Use case:
#   GNS3 Docker containers may be recreated, which changes their SSH host keys.
#   This script removes stale keys for known lab OOB IPs and rescans them.
#
# This is safe only for the controlled PFE lab OOB subnet.

KNOWN_HOSTS_FILE="${KNOWN_HOSTS_FILE:-$HOME/.ssh/known_hosts}"

NODES="${NODES:-10.200.0.11 10.200.0.12 10.200.0.21 10.200.0.22 10.200.0.30 10.200.0.31 10.200.0.32 10.200.0.33 10.200.0.44 10.200.0.45 10.200.0.46}"

mkdir -p "$(dirname "$KNOWN_HOSTS_FILE")"
touch "$KNOWN_HOSTS_FILE"
chmod 600 "$KNOWN_HOSTS_FILE"

echo "[INFO] Known hosts file: $KNOWN_HOSTS_FILE"

for ip in $NODES; do
  echo
  echo "=== Refreshing $ip ==="

  ssh-keygen -f "$KNOWN_HOSTS_FILE" -R "$ip" >/dev/null 2>&1 || true

  if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$ip/22" 2>/dev/null; then
    ssh-keyscan -H -t ed25519,ecdsa,rsa "$ip" >> "$KNOWN_HOSTS_FILE" 2>/dev/null || true
    echo "[OK] Refreshed host key for $ip"
  else
    echo "[WARN] $ip:22 not reachable, skipped"
  fi
done

echo
echo "[OK] GNS3 known_hosts refresh completed."
