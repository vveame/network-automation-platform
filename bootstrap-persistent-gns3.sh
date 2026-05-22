#!/bin/sh

set -e

REPO="/home/gns3/pfe-repo"
PUBKEY_FILE="$REPO/devops.pub"

find_container_any_state() {
  docker ps -a --format '{{.Names}}' | grep "$1" | head -n 1
}

mount_src() {
  CONTAINER="$1"
  DEST="$2"

  docker inspect -f '{{range .Mounts}}{{if eq .Destination "'"$DEST"'"}}{{.Source}}{{end}}{{end}}' "$CONTAINER"
}

require_mount() {
  CONTAINER="$1"
  DEST="$2"

  SRC="$(mount_src "$CONTAINER" "$DEST")"

  if [ -z "$SRC" ]; then
    echo "[ERROR] Persistent directory not found for $CONTAINER:$DEST"
    echo "[INFO] Available mounts are:"
    docker inspect -f '{{range .Mounts}}{{.Destination}} -> {{.Source}}{{println}}{{end}}' "$CONTAINER"
    exit 1
  fi

  echo "$SRC"
}

require_file() {
  FILE="$1"

  if [ ! -f "$FILE" ]; then
    echo "[ERROR] Missing file: $FILE"
    exit 1
  fi
}

install_file() {
  SRC="$1"
  DEST="$2"
  MODE="$3"

  require_file "$SRC"

  echo "[INFO] Installing $SRC -> $DEST"
  sudo install -D -m "$MODE" "$SRC" "$DEST"
}

prepare_frr_common() {
  LOCAL_DIR="$1"
  SSH_DIR="$2"

  sudo mkdir -p "$LOCAL_DIR/security"
  sudo mkdir -p "$SSH_DIR"

  if [ -f "$PUBKEY_FILE" ]; then
    install_file "$PUBKEY_FILE" "$SSH_DIR/authorized_keys" "600"
  else
    echo "[WARN] devops.pub not found. SSH public key will not be installed."
  fi
}

prepare_ovs_common() {
  LOCAL_DIR="$1"
  ROOT_DIR="$2"

  sudo mkdir -p "$LOCAL_DIR/security"
  sudo mkdir -p "$ROOT_DIR/.ssh"

  if [ -f "$PUBKEY_FILE" ]; then
    install_file "$PUBKEY_FILE" "$ROOT_DIR/.ssh/authorized_keys" "600"
  else
    echo "[WARN] devops.pub not found. SSH public key will not be installed."
  fi
}

deploy_frr() {
  NODE_NAME="$1"
  ROUTER_ENV="$2"
  INTERFACES_FILE="$3"
  FRR_CONF="$4"
  EXTRA_SECURITY="$5"

  CONTAINER="$(find_container_any_state "$NODE_NAME")"

  if [ -z "$CONTAINER" ]; then
    echo "[ERROR] Container not found for $NODE_NAME"
    echo "[INFO] Start the node once from GNS3 so its container/persistent dirs are created."
    exit 1
  fi

  echo "[INFO] Deploying FRR persistent config to $NODE_NAME -> $CONTAINER"

  LOCAL_DIR="$(require_mount "$CONTAINER" "/gns3volumes/etc/local")"
  FRR_DIR="$(require_mount "$CONTAINER" "/gns3volumes/etc/frr")"
  SSH_DIR="$(require_mount "$CONTAINER" "/gns3volumes/root/.ssh")"

  prepare_frr_common "$LOCAL_DIR" "$SSH_DIR"

  install_file "$REPO/$ROUTER_ENV" "$LOCAL_DIR/router.env" "644"
  install_file "$REPO/$INTERFACES_FILE" "$LOCAL_DIR/interfaces.sh" "755"
  install_file "$REPO/$FRR_CONF" "$FRR_DIR/frr.conf" "644"

  install_file "$REPO/security/admin-access-control.sh" "$LOCAL_DIR/security/admin-access-control.sh" "755"
  install_file "$REPO/security/ospf-auth.sh" "$LOCAL_DIR/security/ospf-auth.sh" "755"

  if [ -f "$REPO/secrets/ospf.env" ]; then
    install_file "$REPO/secrets/ospf.env" "$LOCAL_DIR/ospf.env" "600"
  else
    echo "[WARN] $REPO/secrets/ospf.env not found. OSPF auth will be skipped."
  fi

  for SEC in $EXTRA_SECURITY; do
    install_file "$REPO/security/$SEC" "$LOCAL_DIR/security/$SEC" "755"
  done
}

deploy_ovs() {
  NODE_NAME="$1"
  OVS_CONFIG="$2"
  OVS_MGMT="$3"

  CONTAINER="$(find_container_any_state "$NODE_NAME")"

  if [ -z "$CONTAINER" ]; then
    echo "[ERROR] Container not found for $NODE_NAME"
    echo "[INFO] Start the node once from GNS3 so its container/persistent dirs are created."
    exit 1
  fi

  echo "[INFO] Deploying OVS persistent config to $NODE_NAME -> $CONTAINER"

  LOCAL_DIR="$(require_mount "$CONTAINER" "/gns3volumes/etc/local")"
  ROOT_DIR="$(require_mount "$CONTAINER" "/gns3volumes/root")"

  prepare_ovs_common "$LOCAL_DIR" "$ROOT_DIR"

  install_file "$REPO/$OVS_CONFIG" "$LOCAL_DIR/ovs-config.sh" "755"
  install_file "$REPO/$OVS_MGMT" "$LOCAL_DIR/ovs-mgmt.sh" "755"
  install_file "$REPO/security/admin-access-control.sh" "$LOCAL_DIR/security/admin-access-control.sh" "755"
}

deploy_dmz_ovs_persistent() {
  NODE_NAME="$1"
  OVS_CONFIG="$2"
  OVS_MGMT="$3"

  CONTAINER="$(find_container_any_state "$NODE_NAME")"

  if [ -z "$CONTAINER" ]; then
    echo "[WARN] Container not found for $NODE_NAME, skipping."
    echo "[INFO] Start the node once from GNS3 so its container/persistent dirs are created."
    return 0
  fi

  echo "[INFO] Deploying DMZ OVS persistent config to $NODE_NAME -> $CONTAINER"

  LOCAL_DIR="$(require_mount "$CONTAINER" "/gns3volumes/etc/local")"
  ROOT_DIR="$(require_mount "$CONTAINER" "/gns3volumes/root")"

  sudo mkdir -p "$LOCAL_DIR/security"
  sudo mkdir -p "$ROOT_DIR/.ssh"

  if [ -f "$PUBKEY_FILE" ]; then
    install_file "$PUBKEY_FILE" "$ROOT_DIR/.ssh/authorized_keys" "600"
  else
    echo "[WARN] devops.pub not found. SSH public key will not be installed."
  fi

  install_file "$REPO/$OVS_CONFIG" "$LOCAL_DIR/ovs-config.sh" "755"
  install_file "$REPO/$OVS_MGMT" "$LOCAL_DIR/ovs-mgmt.sh" "755"
  install_file "$REPO/security/admin-access-control.sh" "$LOCAL_DIR/security/admin-access-control.sh" "755"
}

echo "[INFO] Starting persistent-volume GNS3 bootstrap..."
echo "[INFO] This version works even if containers are stopped or exited."

echo "[INFO] Deploying FRR nodes..."

deploy_frr \
  "Core-FRR-1" \
  "frr/env/core-frr-1.router-env" \
  "frr/interfaces/core-frr-1-interfaces.sh" \
  "frr/routing/core-frr-1.conf" \
  ""

deploy_frr \
  "Core-FRR-2" \
  "frr/env/core-frr-2.router-env" \
  "frr/interfaces/core-frr-2-interfaces.sh" \
  "frr/routing/core-frr-2.conf" \
  ""

deploy_frr \
  "Dist-FRR-1" \
  "frr/env/dist-frr-1.router-env" \
  "frr/interfaces/dist-frr-1-interfaces.sh" \
  "frr/routing/dist-frr-1.conf" \
  "management-vlan-protection.sh"

deploy_frr \
  "Dist-FRR-2" \
  "frr/env/dist-frr-2.router-env" \
  "frr/interfaces/dist-frr-2-interfaces.sh" \
  "frr/routing/dist-frr-2.conf" \
  "management-vlan-protection.sh"

deploy_frr \
  "EdgeRouter-VPNGateway" \
  "frr/env/edge-router.router-env" \
  "frr/interfaces/edge-router-interfaces.sh" \
  "frr/routing/edge-router.conf" \
  "dmz-isolation.sh nat-control.sh"

echo "[INFO] Deploying OVS nodes..."

deploy_ovs \
  "Access-OVS-4" \
  "ovs/access/access-ovs-4.sh" \
  "ovs/management/access-ovs-4-mgmt.sh"

deploy_ovs \
  "Access-OVS-5" \
  "ovs/access/access-ovs-5.sh" \
  "ovs/management/access-ovs-5-mgmt.sh"

deploy_ovs \
  "Access-OVS-6" \
  "ovs/access/access-ovs-6.sh" \
  "ovs/management/access-ovs-6-mgmt.sh"

deploy_ovs \
  "Dist-OVS-1" \
  "ovs/distribution/dist-ovs-1.sh" \
  "ovs/management/dist-ovs-1-mgmt.sh"

deploy_ovs \
  "Dist-OVS-2" \
  "ovs/distribution/dist-ovs-2.sh" \
  "ovs/management/dist-ovs-2-mgmt.sh"

deploy_dmz_ovs_persistent \
  "DMZ-OVS-3" \
  "ovs/dmz/dmz-ovs.sh" \
  "ovs/management/dmz-ovs-3-mgmt.sh"s

echo "[OK] Persistent bootstrap completed."
echo "[INFO] You can now start/restart nodes from GNS3."