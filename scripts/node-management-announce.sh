#!/bin/sh

# Central management-plane announce script.
#
# Purpose:
# - Trigger management-plane learning after GNS3 reload/bootstrap.
# - Avoid duplicating ping logic inside every OVS/FRR script.
# - Used only on SSH-managed infrastructure nodes:
#   OVS, DMZ-OVS, FRR.
#
# Web/DNS services and VPCS do not use this.

set -e

DEVOPS_SERVER="${DEVOPS_SERVER:-192.168.99.10}"
ANNOUNCE_DELAY="${ANNOUNCE_DELAY:-5}"
ANNOUNCE_COUNT="${ANNOUNCE_COUNT:-5}"

echo "[INFO] Management announce target: $DEVOPS_SERVER"
echo "[INFO] Waiting ${ANNOUNCE_DELAY}s before announce..."
sleep "$ANNOUNCE_DELAY"

i=1
while [ "$i" -le "$ANNOUNCE_COUNT" ]; do
  echo "[INFO] Management announce ping attempt $i/$ANNOUNCE_COUNT..."
  ping -c 1 -W 1 "$DEVOPS_SERVER" >/dev/null 2>&1 || true
  i=$((i + 1))
  sleep 1
done

echo "[INFO] Management announce completed."