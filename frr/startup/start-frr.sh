#!/bin/sh

# Ensure FRR config directory exists
mkdir -p /etc/frr

# Create daemons file if missing
if [ ! -f /etc/frr/daemons ]; then
cat > /etc/frr/daemons <<'EOF'
zebra=yes
ospfd=yes
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
vrrpd=no
pathd=no
EOF
fi

# Create vtysh config if missing
if [ ! -f /etc/frr/vtysh.conf ]; then
cat > /etc/frr/vtysh.conf <<'EOF'
service integrated-vtysh-config
EOF
fi

# Create frr.conf if missing
if [ ! -f /etc/frr/frr.conf ]; then
cat > /etc/frr/frr.conf <<'EOF'
frr defaults traditional
hostname frr
no ipv6 forwarding
!
line vty
!
EOF
fi

# Fix ownership if frr user exists
chown -R frr:frr /etc/frr 2>/dev/null || true
chmod 640 /etc/frr/* 2>/dev/null || true

# Start FRR
/usr/lib/frr/frrinit.sh start 2>/dev/null || /etc/init.d/frr start 2>/dev/null || true

# Apply interface config if it exists
if [ -x /etc/local/interfaces.sh ]; then
  /etc/local/interfaces.sh
fi

# Apply security rules if they exist
if [ -x /etc/local/security.sh ]; then
  /etc/local/security.sh
fi

# Keep container alive and console usable
exec sh