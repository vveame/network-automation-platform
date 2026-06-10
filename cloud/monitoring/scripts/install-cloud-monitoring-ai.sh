#!/usr/bin/env bash
set -euo pipefail
set -x

PROM_VERSION="${PROM_VERSION:-3.12.0}"
NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.11.1}"
BLACKBOX_EXPORTER_VERSION="${BLACKBOX_EXPORTER_VERSION:-0.28.0}"
SNMP_EXPORTER_VERSION="${SNMP_EXPORTER_VERSION:-0.30.1}"

REPO_DIR="${REPO_DIR:-/opt/pfe-repo}"

echo "[INFO] Installing cloud monitoring + analyzer runtime"
echo "[INFO] REPO_DIR=$REPO_DIR"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo \
    PROM_VERSION="$PROM_VERSION" \
    NODE_EXPORTER_VERSION="$NODE_EXPORTER_VERSION" \
    BLACKBOX_EXPORTER_VERSION="$BLACKBOX_EXPORTER_VERSION" \
    SNMP_EXPORTER_VERSION="$SNMP_EXPORTER_VERSION" \
    REPO_DIR="$REPO_DIR" \
    "$0" "$@"
fi

dnf install -y \
  curl \
  wget \
  tar \
  gzip \
  python3 \
  python3-pip \
  python3-virtualenv \
  git \
  rsync \
  unzip \
  policycoreutils-python-utils \
  firewalld || true

systemctl enable --now firewalld || true

useradd --no-create-home --shell /sbin/nologin prometheus 2>/dev/null || true
useradd --no-create-home --shell /sbin/nologin node_exporter 2>/dev/null || true
useradd --no-create-home --shell /sbin/nologin blackbox_exporter 2>/dev/null || true
useradd --no-create-home --shell /sbin/nologin snmp_exporter 2>/dev/null || true

mkdir -p \
  /etc/prometheus \
  /etc/prometheus/targets \
  /etc/prometheus/rules \
  /etc/blackbox_exporter \
  /etc/snmp_exporter \
  /etc/grafana/provisioning/datasources \
  /etc/grafana/provisioning/dashboards \
  /etc/grafana/provisioning/alerting \
  /var/lib/prometheus \
  /var/lib/grafana/dashboards/pfe-cloud \
  /opt/pfe-monitoring-downloads \
  /opt/pfe-analyzer-runtime \
  /var/lib/pfe-cloud-analyzer

cd /opt/pfe-monitoring-downloads

install_tar_binary() {
  local name="$1"
  local version="$2"
  local binary="$3"
  local url="$4"

  echo "[INFO] Installing $name $version"
  rm -rf "${name}-${version}.linux-amd64" "${name}-${version}.linux-amd64.tar.gz"

  wget --progress=bar:force "$url" -O "${name}-${version}.linux-amd64.tar.gz"
  tar -xzf "${name}-${version}.linux-amd64.tar.gz"

  install -m 0755 "${name}-${version}.linux-amd64/${binary}" "/usr/local/bin/${binary}"
}

install_tar_binary \
  "prometheus" \
  "$PROM_VERSION" \
  "prometheus" \
  "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz"

install -m 0755 "prometheus-${PROM_VERSION}.linux-amd64/promtool" /usr/local/bin/promtool

install_tar_binary \
  "node_exporter" \
  "$NODE_EXPORTER_VERSION" \
  "node_exporter" \
  "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

install_tar_binary \
  "blackbox_exporter" \
  "$BLACKBOX_EXPORTER_VERSION" \
  "blackbox_exporter" \
  "https://github.com/prometheus/blackbox_exporter/releases/download/v${BLACKBOX_EXPORTER_VERSION}/blackbox_exporter-${BLACKBOX_EXPORTER_VERSION}.linux-amd64.tar.gz"

install_tar_binary \
  "snmp_exporter" \
  "$SNMP_EXPORTER_VERSION" \
  "snmp_exporter" \
  "https://github.com/prometheus/snmp_exporter/releases/download/v${SNMP_EXPORTER_VERSION}/snmp_exporter-${SNMP_EXPORTER_VERSION}.linux-amd64.tar.gz"

# Grafana OSS repository.
cat > /etc/yum.repos.d/grafana.repo <<'GRAFANA_REPO'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
GRAFANA_REPO

dnf install -y grafana

# Copy versioned configuration.
install -m 0644 "$REPO_DIR/cloud/monitoring/prometheus/prometheus.cloud.yml" /etc/prometheus/prometheus.yml
install -m 0644 "$REPO_DIR/cloud/monitoring/blackbox/blackbox.cloud.yml" /etc/blackbox_exporter/blackbox.yml

# Prometheus file_sd targets.
if compgen -G "$REPO_DIR/cloud/monitoring/targets/*.yml" >/dev/null; then
  cp "$REPO_DIR/cloud/monitoring/targets/"*.yml /etc/prometheus/targets/
fi

# Prometheus alert/recording rules.
if [ -d "$REPO_DIR/cloud/monitoring/prometheus/rules" ] && compgen -G "$REPO_DIR/cloud/monitoring/prometheus/rules/*.yml" >/dev/null; then
  cp "$REPO_DIR/cloud/monitoring/prometheus/rules/"*.yml /etc/prometheus/rules/
fi

if [ -d "$REPO_DIR/cloud/monitoring/prometheus/rules" ] && compgen -G "$REPO_DIR/cloud/monitoring/prometheus/rules/*.yaml" >/dev/null; then
  cp "$REPO_DIR/cloud/monitoring/prometheus/rules/"*.yaml /etc/prometheus/rules/
fi

# Grafana datasource provisioning.
install -m 0644 "$REPO_DIR/cloud/monitoring/grafana/provisioning/datasources/prometheus.yml" \
  /etc/grafana/provisioning/datasources/prometheus.yml

# Grafana dashboard provisioning.
if [ -f "$REPO_DIR/cloud/monitoring/grafana/provisioning/dashboards/pfe-cloud-dashboards.yml" ]; then
  install -m 0644 "$REPO_DIR/cloud/monitoring/grafana/provisioning/dashboards/pfe-cloud-dashboards.yml" \
    /etc/grafana/provisioning/dashboards/pfe-cloud-dashboards.yml
fi

# Grafana alerting provisioning.
if [ -d "$REPO_DIR/cloud/monitoring/grafana/provisioning/alerting" ]; then
  find "$REPO_DIR/cloud/monitoring/grafana/provisioning/alerting" -type f \( -name "*.yml" -o -name "*.yaml" -o -name "*.json" \) -print0 | \
    xargs -0 -r cp -t /etc/grafana/provisioning/alerting/
fi

# Grafana dashboard JSON files.
if [ -d "$REPO_DIR/cloud/monitoring/grafana/dashboards" ]; then
  find "$REPO_DIR/cloud/monitoring/grafana/dashboards" -type f -name "*.json" -print0 | \
    xargs -0 -r cp -t /var/lib/grafana/dashboards/pfe-cloud/
fi

echo "[INFO] Installed Prometheus targets:"
find /etc/prometheus/targets -maxdepth 1 -type f -print | sort || true

echo "[INFO] Installed Prometheus rules:"
find /etc/prometheus/rules -maxdepth 1 -type f -print | sort || true

echo "[INFO] Installed Grafana alerting provisioning files:"
find /etc/grafana/provisioning/alerting -maxdepth 1 -type f -print | sort || true

echo "[INFO] Installed Grafana dashboard files:"
find /var/lib/grafana/dashboards/pfe-cloud -maxdepth 1 -type f -print | sort || true

# SNMP config contains real credentials. It is copied by deploy script if available.
if [ -f /tmp/pfe-snmp.yml ]; then
  install -m 0600 /tmp/pfe-snmp.yml /etc/snmp_exporter/snmp.yml
elif [ -f /etc/prometheus/snmp.yml ]; then
  install -m 0600 /etc/prometheus/snmp.yml /etc/snmp_exporter/snmp.yml
else
  echo "[WARN] No SNMP Exporter config found."
  echo "[WARN] SNMP job will fail until /etc/snmp_exporter/snmp.yml is created."
fi

chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
chown -R blackbox_exporter:blackbox_exporter /etc/blackbox_exporter
chown -R snmp_exporter:snmp_exporter /etc/snmp_exporter
chown -R grafana:grafana /var/lib/grafana/dashboards || true

cat > /etc/systemd/system/prometheus.service <<'SERVICE'
[Unit]
Description=PFE Cloud Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.listen-address=0.0.0.0:9090 \
  --web.enable-lifecycle
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

cat > /etc/systemd/system/node_exporter.service <<'SERVICE'
[Unit]
Description=PFE Cloud Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=0.0.0.0:9100
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

cat > /etc/systemd/system/blackbox_exporter.service <<'SERVICE'
[Unit]
Description=PFE Cloud Blackbox Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=blackbox_exporter
Group=blackbox_exporter
Type=simple
ExecStart=/usr/local/bin/blackbox_exporter \
  --config.file=/etc/blackbox_exporter/blackbox.yml \
  --web.listen-address=0.0.0.0:9115
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

cat > /etc/systemd/system/snmp_exporter.service <<'SERVICE'
[Unit]
Description=PFE Cloud SNMP Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=snmp_exporter
Group=snmp_exporter
Type=simple
ExecStart=/usr/local/bin/snmp_exporter \
  --config.file=/etc/snmp_exporter/snmp.yml \
  --web.listen-address=0.0.0.0:9116
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

# Prepare analyzer + ML Python runtime.
python3 -m venv /opt/pfe-analyzer-runtime/.venv
/opt/pfe-analyzer-runtime/.venv/bin/python -m pip install --upgrade pip

if [ -f "$REPO_DIR/cloud/analyzer/requirements.txt" ]; then
  /opt/pfe-analyzer-runtime/.venv/bin/pip install -r "$REPO_DIR/cloud/analyzer/requirements.txt"
fi

if [ -f "$REPO_DIR/cloud/analyzer/ml/requirements.txt" ]; then
  /opt/pfe-analyzer-runtime/.venv/bin/pip install -r "$REPO_DIR/cloud/analyzer/ml/requirements.txt"
fi

# If analyzer has no base requirements file, install minimum runtime dependencies.
 /opt/pfe-analyzer-runtime/.venv/bin/pip install pandas numpy scikit-learn joblib boto3 pyyaml requests >/dev/null

# Open local firewall for monitoring services.
firewall-cmd --permanent --add-port=9090/tcp || true
firewall-cmd --permanent --add-port=3000/tcp || true
firewall-cmd --permanent --add-port=9100/tcp || true
firewall-cmd --permanent --add-port=9115/tcp || true
firewall-cmd --permanent --add-port=9116/tcp || true
firewall-cmd --reload || true

promtool check config /etc/prometheus/prometheus.yml

systemctl daemon-reload
systemctl enable --now node_exporter
systemctl enable --now blackbox_exporter
systemctl enable --now snmp_exporter
systemctl enable --now prometheus
systemctl enable --now grafana-server

echo "[OK] Cloud monitoring + analyzer runtime installed."

systemctl --no-pager --full status prometheus node_exporter blackbox_exporter snmp_exporter grafana-server || true
