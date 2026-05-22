#!/bin/sh

set -e

REPO="/home/gns3/pfe-repo"
PUBKEY_FILE="$REPO/devops.pub"

find_container() {
  docker ps --format '{{.Names}}' | grep "$1" | head -n 1
}

require_file() {
  FILE="$1"

  if [ ! -f "$FILE" ]; then
    echo "[ERROR] Missing file: $FILE"
    exit 1
  fi
}

write_file() {
  CONTAINER="$1"
  SRC="$2"
  DEST="$3"
  MODE="$4"

  require_file "$SRC"

  echo "[INFO] Writing $SRC -> $CONTAINER:$DEST"

  docker exec "$CONTAINER" sh -c "mkdir -p \"$(dirname "$DEST")\""
  docker exec -i "$CONTAINER" sh -c "cat > \"$DEST\"" < "$SRC"
  docker exec "$CONTAINER" sh -c "chmod $MODE \"$DEST\""
}

prepare_container() {
  CONTAINER="$1"

  docker exec "$CONTAINER" sh -c 'mkdir -p /etc/local/security /etc/frr /root/.ssh'

  if [ -f "$PUBKEY_FILE" ]; then
    echo "[INFO] Installing DevOps SSH public key in $CONTAINER"
    docker exec -i "$CONTAINER" sh -c 'cat > /root/.ssh/authorized_keys' < "$PUBKEY_FILE"
    docker exec "$CONTAINER" sh -c 'chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys'
  else
    echo "[WARN] devops.pub not found. SSH public key will not be copied."
  fi
}

deploy_frr() {
  NODE_NAME="$1"
  ROUTER_ENV="$2"
  INTERFACES_FILE="$3"
  FRR_CONF="$4"
  EXTRA_SECURITY="$5"

  CONTAINER="$(find_container "$NODE_NAME")"

  if [ -z "$CONTAINER" ]; then
    echo "[ERROR] Running container not found for $NODE_NAME"
    echo "[INFO] Start this node from GNS3 first, then rerun bootstrap."
    exit 1
  fi

  echo "[INFO] Deploying FRR config to $NODE_NAME -> $CONTAINER"

  prepare_container "$CONTAINER"

  write_file "$CONTAINER" "$REPO/$ROUTER_ENV" "/etc/local/router.env" "644"
  write_file "$CONTAINER" "$REPO/$INTERFACES_FILE" "/etc/local/interfaces.sh" "755"
  write_file "$CONTAINER" "$REPO/$FRR_CONF" "/etc/frr/frr.conf" "644"

  write_file "$CONTAINER" "$REPO/security/admin-access-control.sh" "/etc/local/security/admin-access-control.sh" "755"
  write_file "$CONTAINER" "$REPO/security/ospf-auth.sh" "/etc/local/security/ospf-auth.sh" "755"

  if [ -f "$REPO/secrets/ospf.env" ]; then
    write_file "$CONTAINER" "$REPO/secrets/ospf.env" "/etc/local/ospf.env" "600"
  else
    echo "[WARN] $REPO/secrets/ospf.env not found. OSPF auth will be skipped."
  fi

  for SEC in $EXTRA_SECURITY; do
    write_file "$CONTAINER" "$REPO/security/$SEC" "/etc/local/security/$SEC" "755"
  done
}

deploy_ovs() {
  NODE_NAME="$1"
  OVS_CONFIG="$2"
  OVS_MGMT="$3"

  CONTAINER="$(find_container "$NODE_NAME")"

  if [ -z "$CONTAINER" ]; then
    echo "[ERROR] Running container not found for $NODE_NAME"
    echo "[INFO] Start this node from GNS3 first, then rerun bootstrap."
    exit 1
  fi

  echo "[INFO] Deploying OVS config to $NODE_NAME -> $CONTAINER"

  prepare_container "$CONTAINER"

  write_file "$CONTAINER" "$REPO/$OVS_CONFIG" "/etc/local/ovs-config.sh" "755"
  write_file "$CONTAINER" "$REPO/$OVS_MGMT" "/etc/local/ovs-mgmt.sh" "755"
  write_file "$CONTAINER" "$REPO/security/admin-access-control.sh" "/etc/local/security/admin-access-control.sh" "755"
}

deploy_dmz_ovs() {
  NODE_NAME="$1"
  OVS_CONFIG="$2"
  OVS_MGMT="$3"

  CONTAINER="$(find_container "$NODE_NAME")"

  if [ -z "$CONTAINER" ]; then
    echo "[WARN] Running container not found for $NODE_NAME, skipping."
    return 0
  fi

  echo "[INFO] Deploying DMZ OVS config to $NODE_NAME -> $CONTAINER"

  docker exec "$CONTAINER" sh -c 'mkdir -p /etc/local/security /root/.ssh'

  if [ -f "$PUBKEY_FILE" ]; then
    echo "[INFO] Installing DevOps SSH public key in $CONTAINER"
    docker exec -i "$CONTAINER" sh -c 'cat > /root/.ssh/authorized_keys' < "$PUBKEY_FILE"
    docker exec "$CONTAINER" sh -c 'chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys'
  else
    echo "[WARN] devops.pub not found. SSH public key will not be copied."
  fi

  write_file "$CONTAINER" "$REPO/$OVS_CONFIG" "/etc/local/ovs-config.sh" "755"
  write_file "$CONTAINER" "$REPO/$OVS_MGMT" "/etc/local/ovs-mgmt.sh" "755"
  write_file "$CONTAINER" "$REPO/security/admin-access-control.sh" "/etc/local/security/admin-access-control.sh" "755"

  echo "[INFO] Applying DMZ OVS bridge config on $NODE_NAME..."
  docker exec "$CONTAINER" sh -c "/etc/local/ovs-config.sh"

  echo "[INFO] Applying DMZ OVS management config on $NODE_NAME..."
  docker exec "$CONTAINER" sh -c "/etc/local/ovs-mgmt.sh"

  echo "[INFO] Applying admin access control on $NODE_NAME..."
  docker exec "$CONTAINER" sh -c "/etc/local/security/admin-access-control.sh" || true
}

echo "[INFO] Starting running-container GNS3 bootstrap..."
echo "[INFO] Make sure all GNS3 Docker nodes are currently started."

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

deploy_dmz_ovs \
  "DMZ-OVS-3" \
  "ovs/dmz/dmz-ovs.sh" \
  "ovs/management/dmz-ovs-3-mgmt.sh"

echo "[OK] Bootstrap completed."
echo "[IMPORTANT] Stop all nodes, then start them again from GNS3."