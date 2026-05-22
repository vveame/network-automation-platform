#!/bin/sh

# Apply/run management-plane announce without reapplying full bootstrap.
#
# Run from GNS3 VM:
#   ./scripts/apply-management-announce.sh
#
# Optional:
#   ./scripts/apply-management-announce.sh install
#   ./scripts/apply-management-announce.sh run
#   ./scripts/apply-management-announce.sh all

set -e

REPO="${REPO:-/home/gns3/pfe-repo}"
ANNOUNCE_SRC="$REPO/scripts/node-management-announce.sh"
MODE="${1:-all}"

DEVOPS_SERVER="${DEVOPS_SERVER:-192.168.99.10}"
ANNOUNCE_DELAY="${ANNOUNCE_DELAY:-0}"
ANNOUNCE_COUNT="${ANNOUNCE_COUNT:-10}"

NODES="
Dist-OVS-1
Dist-OVS-2
Access-OVS-4
Access-OVS-5
Access-OVS-6
"

find_container() {
  docker ps --format '{{.Names}}' | grep "$1" | head -n 1
}

install_announce() {
  NODE_NAME="$1"
  CONTAINER="$(find_container "$NODE_NAME")"

  if [ -z "$CONTAINER" ]; then
    echo "[WARN] Running container not found for $NODE_NAME, skipping install."
    return 0
  fi

  if [ ! -f "$ANNOUNCE_SRC" ]; then
    echo "[ERROR] Missing announce source file: $ANNOUNCE_SRC"
    exit 1
  fi

  echo "[INFO] Installing announce script on $NODE_NAME -> $CONTAINER"

  docker exec "$CONTAINER" sh -c 'mkdir -p /etc/local'
  docker cp "$ANNOUNCE_SRC" "$CONTAINER:/etc/local/management-announce.sh"
  docker exec "$CONTAINER" sh -c 'chmod 755 /etc/local/management-announce.sh'
}

run_announce() {
  NODE_NAME="$1"
  CONTAINER="$(find_container "$NODE_NAME")"

  if [ -z "$CONTAINER" ]; then
    echo "[WARN] Running container not found for $NODE_NAME, skipping announce."
    return 0
  fi

  echo "[INFO] Running management announce on $NODE_NAME -> $CONTAINER"

  docker exec "$CONTAINER" sh -c "
    if [ -x /etc/local/management-announce.sh ]; then
      DEVOPS_SERVER='$DEVOPS_SERVER' \
      ANNOUNCE_DELAY='$ANNOUNCE_DELAY' \
      ANNOUNCE_COUNT='$ANNOUNCE_COUNT' \
      /etc/local/management-announce.sh
    else
      echo '[WARN] /etc/local/management-announce.sh not found or not executable.'
    fi
  " || true
}

echo "[INFO] Management announce utility"
echo "[INFO] Mode: $MODE"
echo "[INFO] DevOps server: $DEVOPS_SERVER"
echo "[INFO] Announce count: $ANNOUNCE_COUNT"

case "$MODE" in
  install)
    for NODE in $NODES; do
      install_announce "$NODE"
    done
    ;;

  run)
    for NODE in $NODES; do
      run_announce "$NODE"
    done
    ;;

  all)
    for NODE in $NODES; do
      install_announce "$NODE"
    done

    for NODE in $NODES; do
      run_announce "$NODE"
    done
    ;;

  *)
    echo "[ERROR] Unknown mode: $MODE"
    echo "Usage: $0 [install|run|all]"
    exit 1
    ;;
esac

echo "[OK] Management announce operation completed."