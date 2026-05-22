#!/bin/sh

set -e

find_container() {
  docker ps --format '{{.Names}}' | grep "$1" | head -n 1
}

DIST_FRR_1="$(find_container 'Dist-FRR-1')"
WEB="$(find_container 'Web-Server-Nginx')"
DNS="$(find_container 'DNS-1')"

if [ -z "$DIST_FRR_1" ] || [ -z "$WEB" ] || [ -z "$DNS" ]; then
  echo "[ERROR] Required containers are not running."
  echo "[INFO] Dist-FRR-1=$DIST_FRR_1 Web=$WEB DNS=$DNS"
  exit 1
fi

echo "[TEST] Checking containers..."
docker ps --filter "name=GNS3"

docker exec "$DIST_FRR_1" vtysh -c "show vrrp"
docker exec "$WEB" sh -c "curl -s http://127.0.0.1"
docker exec "$DNS" sh -c "nslookup web.pfe.local 127.0.0.1"

echo "[OK] Basic on-prem validation completed."