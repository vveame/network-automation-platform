#!/usr/bin/env bash
set -uo pipefail

# Optional SNMPv3 startup for OVS containers.
# SNMP must never prevent the switch from starting.

SNMP_ENV_FILE="/etc/local/snmp/snmp.env"
SNMP_TEMPLATE_FILE="/etc/local/snmp/snmpd.conf.template"
SNMP_CONFIG_FILE="/etc/snmp/snmpd.conf"
NET_SNMP_PERSISTENT_FILE="/var/lib/net-snmp/snmpd.conf"

if [ ! -f "$SNMP_ENV_FILE" ]; then
  echo "[SNMP] No SNMP env file found. SNMP disabled."
  exit 0
fi

# shellcheck disable=SC1090
source "$SNMP_ENV_FILE"

if [ "${SNMP_ENABLE:-false}" != "true" ]; then
  echo "[SNMP] SNMP_ENABLE is not true. SNMP disabled."
  exit 0
fi

if [ -z "${SNMP_V3_USERNAME:-}" ] || \
   [ -z "${SNMP_V3_AUTH_PASSWORD:-}" ] || \
   [ -z "${SNMP_V3_PRIV_PASSWORD:-}" ]; then
  echo "[SNMP][WARN] Missing SNMPv3 variables. SNMP disabled."
  exit 0
fi

if [ ! -f "$SNMP_TEMPLATE_FILE" ]; then
  echo "[SNMP][WARN] Missing SNMP template: $SNMP_TEMPLATE_FILE"
  echo "[SNMP][WARN] SNMP disabled."
  exit 0
fi

SNMP_AGENT_PORT="${SNMP_AGENT_PORT:-1161}"

mkdir -p /etc/snmp /var/lib/net-snmp

sed \
  -e "s|__SNMP_V3_USERNAME__|${SNMP_V3_USERNAME}|g" \
  "$SNMP_TEMPLATE_FILE" > "$SNMP_CONFIG_FILE"

chmod 600 "$SNMP_CONFIG_FILE"

# Recreate the SNMPv3 user on every startup so the container is reproducible.
cat > "$NET_SNMP_PERSISTENT_FILE" <<SNMPUSER
createUser ${SNMP_V3_USERNAME} SHA "${SNMP_V3_AUTH_PASSWORD}" AES "${SNMP_V3_PRIV_PASSWORD}"
SNMPUSER

chmod 600 "$NET_SNMP_PERSISTENT_FILE"

echo "[SNMP] Starting snmpd on UDP/${SNMP_AGENT_PORT} with SNMPv3 authPriv."

pkill snmpd 2>/dev/null || true

if snmpd -Lo -c "$SNMP_CONFIG_FILE" "udp:${SNMP_AGENT_PORT}"; then
  sleep 1

  if command -v ss >/dev/null 2>&1; then
    if ss -lunp | grep -q ":${SNMP_AGENT_PORT}"; then
      echo "[SNMP] snmpd is listening on UDP/${SNMP_AGENT_PORT}."
    else
      echo "[SNMP][WARN] snmpd started but UDP/${SNMP_AGENT_PORT} listener was not detected."
    fi
  else
    echo "[SNMP] snmpd started. 'ss' not available for listener check."
  fi
else
  echo "[SNMP][WARN] snmpd failed to start. Continuing switch startup."
fi

exit 0
