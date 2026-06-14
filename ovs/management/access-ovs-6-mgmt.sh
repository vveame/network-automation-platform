#!/bin/sh
set -e

# Access-OVS-6 no longer uses VLAN 99 as the automation path.
# Final management is provided by the dedicated OOB interface:
# eth4 -> 10.200.0.46/24
#
# This script is kept as a compatibility hook because bootstrap still installs
# ovs-mgmt.sh for OVS nodes, but it must not recreate mgmt0 or set a VLAN 99
# default route.

echo "[INFO] Access-OVS-6 uses dedicated OOB management on eth4."
echo "[INFO] Skipping legacy VLAN 99 mgmt0 configuration."
ip -br addr show eth4 2>/dev/null || true
ip route || true
