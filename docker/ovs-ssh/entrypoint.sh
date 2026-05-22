#!/bin/sh

set -e

echo "[BOOT] Starting OVS SSH-enabled container..."

mkdir -p /etc/local
mkdir -p /etc/local/security
mkdir -p /etc/openvswitch
mkdir -p /var/run/openvswitch
mkdir -p /var/log/openvswitch
mkdir -p /run/sshd
mkdir -p /root/.ssh

chmod 700 /root/.ssh 2>/dev/null || true

# 1. Configure SSH

ssh-keygen -A 2>/dev/null || true

if [ -n "$DEVOPS_SSH_PUBLIC_KEY" ]; then
  echo "$DEVOPS_SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
fi

if [ -f /etc/ssh/sshd_config ]; then
  sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config || true
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config || true
  sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config || true
fi

# 2. Start Open vSwitch database and daemon

echo "[BOOT] Starting Open vSwitch services..."

if [ ! -f /etc/openvswitch/conf.db ]; then
  echo "[BOOT] Creating OVS database..."
  ovsdb-tool create /etc/openvswitch/conf.db /usr/share/openvswitch/vswitch.ovsschema
fi

ovsdb-server \
  --remote=punix:/var/run/openvswitch/db.sock \
  --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
  --pidfile \
  --detach \
  --log-file

ovs-vsctl --no-wait init

ovs-vswitchd \
  --pidfile \
  --detach \
  --log-file

sleep 1

ovs-vsctl show || true

# 3. Apply OVS bridge/VLAN/trunk configuration

if [ -x /etc/local/ovs-config.sh ]; then
  echo "[BOOT] Applying OVS configuration..."
  /etc/local/ovs-config.sh
else
  echo "[BOOT] No /etc/local/ovs-config.sh found or not executable."
fi

# 4. Apply OVS management IP configuration

if [ -x /etc/local/ovs-mgmt.sh ]; then
  echo "[BOOT] Applying OVS management IP..."
  /etc/local/ovs-mgmt.sh || true
else
  echo "[BOOT] No /etc/local/ovs-mgmt.sh found, skipping management IP."
fi

# 5. Apply admin access control

if [ -x /etc/local/security/admin-access-control.sh ]; then
  echo "[BOOT] Applying admin access control..."
  /etc/local/security/admin-access-control.sh || true
else
  echo "[BOOT] admin-access-control.sh not found, skipping."
fi

# 6. Announce management reachability to DevOps server

if [ -x /etc/local/management-announce.sh ]; then
  echo "[BOOT] Running management announce..."
  DEVOPS_SERVER="${DEVOPS_SERVER:-192.168.99.10}" \
  ANNOUNCE_DELAY="${ANNOUNCE_DELAY:-10}" \
  ANNOUNCE_COUNT="${ANNOUNCE_COUNT:-10}" \
  /etc/local/management-announce.sh || true
else
  echo "[BOOT] management-announce.sh not found, skipping."
fi

# 7. Ensure root can use key-only SSH

echo "[BOOT] Ensuring root account is usable for key-only SSH..."

if command -v passwd >/dev/null 2>&1; then
  passwd -d root 2>/dev/null || true
fi

if [ -f /etc/shadow ]; then
  sed -i 's/^root:[!*][^:]*:/root::/' /etc/shadow
fi

# 8. Start SSH daemon

if command -v sshd >/dev/null 2>&1; then
  echo "[BOOT] Starting SSH daemon..."
  /usr/sbin/sshd || true
else
  echo "[BOOT] sshd not found. Build the ovs-ssh image to enable SSH."
fi

echo "[BOOT] Startup completed."

exec sh