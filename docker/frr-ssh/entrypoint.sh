#!/bin/sh

set -e

echo "[BOOT] Starting FRR SSH-enabled container..."

mkdir -p /etc/frr
mkdir -p /etc/local
mkdir -p /etc/local/security
mkdir -p /var/log/frr
mkdir -p /var/run/frr
mkdir -p /run/sshd
mkdir -p /root/.ssh

chown -R frr:frr /var/log/frr /var/run/frr 2>/dev/null || true
chmod 700 /root/.ssh 2>/dev/null || true

# 0. Load node-specific environment variables

if [ -f /etc/local/router.env ]; then
  echo "[BOOT] Loading router environment file..."
  . /etc/local/router.env

  # Normalize possible Windows CRLF values
  ROUTER_NAME="$(printf '%s' "$ROUTER_NAME" | tr -d '\r')"
  ROUTER_HOSTNAME="$(printf '%s' "$ROUTER_HOSTNAME" | tr -d '\r')"
  ROUTER_ROLE="$(printf '%s' "$ROUTER_ROLE" | tr -d '\r')"
  ENABLE_NAT="$(printf '%s' "$ENABLE_NAT" | tr -d '\r')"
  EXTERNAL_IFACE="$(printf '%s' "$EXTERNAL_IFACE" | tr -d '\r')"
fi

if [ -n "$ROUTER_HOSTNAME" ]; then
  echo "[BOOT] Setting Linux hostname to $ROUTER_HOSTNAME"
  hostname "$ROUTER_HOSTNAME" || true
fi

# 1. Initialize FRR files

echo "[BOOT] Configuring /etc/frr/daemons"

cat > /etc/frr/daemons <<'EOF'
zebra=yes
ospfd=yes
vrrpd=yes
staticd=yes
bgpd=no
ripd=no
ripngd=no
isisd=no
pimd=no
ldpd=no
nhrpd=no
eigrpd=no
babeld=no
sharpd=no
pbrd=no
bfdd=no
fabricd=no
pathd=no
EOF

if [ ! -f /etc/frr/vtysh.conf ]; then
  echo "[BOOT] Creating /etc/frr/vtysh.conf"
  cat > /etc/frr/vtysh.conf <<'EOF'
service integrated-vtysh-config
EOF
fi

if [ ! -f /etc/frr/frr.conf ]; then
  echo "[BOOT] Creating minimal /etc/frr/frr.conf"
  cat > /etc/frr/frr.conf <<'EOF'
frr defaults traditional
hostname frr
no ipv6 forwarding
!
line vty
!
EOF
fi

chown -R frr:frr /etc/frr 2>/dev/null || true
chmod 640 /etc/frr/* 2>/dev/null || true

# 2. Configure SSH

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

# 3. Apply interface configuration before starting FRR

if [ -f /etc/local/interfaces.sh ]; then
  echo "[BOOT] Applying interface configuration..."
  /etc/local/interfaces.sh
else
  echo "[BOOT] No /etc/local/interfaces.sh found or not executable."
fi

# Apply OOB management interface configuration

if [ -x /etc/local/oob-mgmt.sh ]; then
  echo "[BOOT] Applying OOB management configuration..."
  /etc/local/oob-mgmt.sh || true
else
  echo "[BOOT] No /etc/local/oob-mgmt.sh found, skipping OOB management."
fi

# 4. Start FRR daemons

echo "[BOOT] Starting FRR daemons..."
/usr/lib/frr/frrinit.sh start 2>/dev/null || /etc/init.d/frr start 2>/dev/null || true

# 5. Apply OSPF authentication

if [ -f /etc/local/security/ospf-auth.sh ] && [ -f /etc/local/ospf.env ]; then
  if [ -n "$ROUTER_NAME" ]; then
    echo "[BOOT] Applying OSPF authentication for $ROUTER_NAME..."
    /etc/local/security/ospf-auth.sh "$ROUTER_NAME" || true
  else
    echo "[BOOT] ROUTER_NAME not set, skipping OSPF authentication."
  fi
else
  echo "[BOOT] OSPF auth script or secret not found, skipping."
fi

# 6. Apply role-specific security rules

case "$ROUTER_ROLE" in
  distribution)
    echo "[BOOT] Router role: distribution"

    if [ -f /etc/local/security/management-vlan-protection.sh ]; then
      echo "[BOOT] Applying management VLAN protection..."
      /etc/local/security/management-vlan-protection.sh || true
    else
      echo "[BOOT] management-vlan-protection.sh not found, skipping."
    fi
    ;;

  core)
    echo "[BOOT] Router role: core"
    echo "[BOOT] No management VLAN, DMZ, or NAT rules required on core routers."
    ;;

  edge)
    echo "[BOOT] Router role: edge"

    if [ -f /etc/local/security/dmz-isolation.sh ]; then
      echo "[BOOT] Applying DMZ isolation..."
      /etc/local/security/dmz-isolation.sh || true
    else
      echo "[BOOT] dmz-isolation.sh not found, skipping."
    fi

    if [ "$ENABLE_NAT" = "true" ] && [ -f /etc/local/security/nat-control.sh ]; then
      echo "[BOOT] Applying NAT control..."
      /etc/local/security/nat-control.sh || true
    else
      echo "[BOOT] NAT disabled or nat-control.sh not found."
    fi
    ;;

  *)
    echo "[BOOT] ROUTER_ROLE not set or unknown, skipping role-specific security."
    ;;
esac

# 7. Apply admin access control on every managed FRR router

if [ -f /etc/local/security/admin-access-control.sh ]; then
  echo "[BOOT] Applying admin access control..."
  /etc/local/security/admin-access-control.sh || true
else
  echo "[BOOT] admin-access-control.sh not found, skipping."
fi

# 8. Unlock root for key-only SSH access.
# Some base images keep root locked in /etc/shadow.
# OpenSSH rejects locked accounts before checking authorized_keys.
echo "[BOOT] Ensuring root account is usable for key-only SSH..."

if command -v passwd >/dev/null 2>&1; then
  passwd -d root 2>/dev/null || true
fi

if [ -f /etc/shadow ]; then
  sed -i 's/^root:[!*][^:]*:/root::/' /etc/shadow
fi

# Start SNMP agent if /etc/local/snmp/snmp.env exists.
# SNMP is optional and must never prevent the router from starting.
if [ -x /start-snmp.sh ]; then
    echo "[BOOT] Starting optional SNMP service..."
    /start-snmp.sh || echo "[BOOT][WARN] SNMP startup failed, continuing router startup."
fi

# 10. Start SSH daemon

if command -v sshd >/dev/null 2>&1; then
  echo "[BOOT] Starting SSH daemon..."

# PFE cloud monitoring access.
# Allows the private AWS monitoring EC2 to scrape local SNMPv3 endpoints
# after Prometheus is moved to the cloud.
if [ -x /etc/local/security/cloud-monitoring-access.sh ]; then
  echo "[INFO] Applying cloud monitoring access rules..."
  CLOUD_MONITORING_IP="${CLOUD_MONITORING_IP:-10.50.30.154}" \
  CLOUD_MONITORING_EXTRA_IPS="${CLOUD_MONITORING_EXTRA_IPS:-10.255.0.1}"\
  AWS_VPC_CIDR="${AWS_VPC_CIDR:-10.50.0.0/16}" \
  EDGE_OOB_GW="${EDGE_OOB_GW:-10.200.0.30}" \
    /etc/local/security/cloud-monitoring-access.sh || \
    echo "[WARN] Cloud monitoring access rule application failed."
else
  echo "[INFO] No cloud monitoring access script found, skipping."
fi

  /usr/sbin/sshd || true
else
  echo "[BOOT] sshd not found. Build the frr-ssh image to enable SSH."
fi

echo "[BOOT] Startup completed."

exec sh