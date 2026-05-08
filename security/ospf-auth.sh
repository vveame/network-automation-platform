#!/bin/sh

# Apply OSPF authentication on FRR routers.

# Usage:
#   ./ospf-auth.sh <router-name>

# Requirements:
#   - Run this script inside the target FRR router/container.
#   - A local secrets file must exist at: /etc/local/ospf.env
#     or in the repo at: ./secrets/ospf.env

set -e

ROUTER_NAME="$1"

if [ -z "$ROUTER_NAME" ]; then
  echo "Error: router name is required."
  echo "Usage: $0 <dist-frr-1|dist-frr-2|core-frr-1|core-frr-2|edge-router>"
  exit 1
fi

# Load secrets.
# Preferred path inside router container:
if [ -f /etc/local/ospf.env ]; then
  . /etc/local/ospf.env
# Local repo path, when running from repository root:
elif [ -f ./secrets/ospf.env ]; then
  . ./secrets/ospf.env
# Local repo path, when running from security/ folder:
elif [ -f ../secrets/ospf.env ]; then
  . ../secrets/ospf.env
else
  echo "Error: OSPF secret file not found."
  echo "Create one of:"
  echo "  /etc/local/ospf.env"
  echo "  ./secrets/ospf.env"
  echo "  ../secrets/ospf.env"
  exit 1
fi

OSPF_KEY_ID="$(printf '%s' "$OSPF_KEY_ID" | tr -d '\r')"
OSPF_MD5_KEY="$(printf '%s' "$OSPF_MD5_KEY" | tr -d '\r')"

if [ -z "$OSPF_KEY_ID" ] || [ -z "$OSPF_MD5_KEY" ]; then
  echo "Error: OSPF_KEY_ID or OSPF_MD5_KEY is missing."
  exit 1
fi

apply_auth() {
  INTERFACE="$1"

  vtysh <<EOF
conf t
interface ${INTERFACE}
 ip ospf authentication message-digest
 ip ospf message-digest-key ${OSPF_KEY_ID} md5 ${OSPF_MD5_KEY}
exit
end
write memory
EOF
}

case "$ROUTER_NAME" in
  dist-frr-1)
    # Dist-FRR-1:
    # eth1 -> Core-FRR-1
    # eth2 -> Core-FRR-2
    apply_auth eth1
    apply_auth eth2
    ;;

  dist-frr-2)
    # Dist-FRR-2:
    # eth1 -> Core-FRR-1
    # eth2 -> Core-FRR-2
    apply_auth eth1
    apply_auth eth2
    ;;

  core-frr-1)
    # Core-FRR-1:
    # eth0 -> Dist-FRR-1
    # eth1 -> Dist-FRR-2
    # eth2 -> EdgeRouter
    apply_auth eth0
    apply_auth eth1
    apply_auth eth2
    ;;

  core-frr-2)
    # Core-FRR-2:
    # eth0 -> Dist-FRR-1
    # eth1 -> Dist-FRR-2
    # eth2 -> EdgeRouter
    apply_auth eth0
    apply_auth eth1
    apply_auth eth2
    ;;

  edge-router)
    # EdgeRouter:
    # eth0 -> Core-FRR-1
    # eth1 -> Core-FRR-2
    # eth2 -> DMZ, passive, no authentication needed
    apply_auth eth0
    apply_auth eth1
    ;;

  *)
    echo "Error: unknown router name: $ROUTER_NAME"
    echo "Allowed values:"
    echo "  dist-frr-1"
    echo "  dist-frr-2"
    echo "  core-frr-1"
    echo "  core-frr-2"
    echo "  edge-router"
    exit 1
    ;;
esac

echo "OSPF authentication applied on ${ROUTER_NAME}."
vtysh -c "show ip ospf neighbor"