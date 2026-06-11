#!/usr/bin/env bash
set -euo pipefail

# Background SSH tunnel to AWS private monitoring EC2.
#
# Run from DevOps VM after the EdgeRouter/AWS hybrid tunnel is restored.
#
# Local URLs:
#   Prometheus: http://127.0.0.1:19090
#   Grafana:    http://127.0.0.1:13000
#
# This does NOT open AWS security groups.
# This does NOT expose Prometheus/Grafana publicly.
# It only forwards local DevOps ports to the monitoring EC2 over SSH.

ACTION="${1:-start}"

AWS_MONITORING_HOST="${AWS_MONITORING_HOST:-10.50.30.154}"
AWS_MONITORING_USER="${AWS_MONITORING_USER:-ec2-user}"
AWS_MONITORING_KEY="${AWS_MONITORING_KEY:-$HOME/.ssh/pfe-aws-tunnel}"

LOCAL_BIND="${LOCAL_BIND:-127.0.0.1}"
LOCAL_PROMETHEUS_PORT="${LOCAL_PROMETHEUS_PORT:-19090}"
LOCAL_GRAFANA_PORT="${LOCAL_GRAFANA_PORT:-13000}"

REMOTE_PROMETHEUS_HOST="${REMOTE_PROMETHEUS_HOST:-127.0.0.1}"
REMOTE_PROMETHEUS_PORT="${REMOTE_PROMETHEUS_PORT:-9090}"
REMOTE_GRAFANA_HOST="${REMOTE_GRAFANA_HOST:-127.0.0.1}"
REMOTE_GRAFANA_PORT="${REMOTE_GRAFANA_PORT:-3000}"

SOCKET="${SOCKET:-/tmp/pfe-cloud-monitoring-ui-tunnel.sock}"

ssh_base() {
  ssh \
    -i "$AWS_MONITORING_KEY" \
    -S "$SOCKET" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    "$AWS_MONITORING_USER@$AWS_MONITORING_HOST" "$@"
}

is_running() {
  ssh_base -O check >/dev/null 2>&1
}

start_tunnel() {
  if [ ! -f "$AWS_MONITORING_KEY" ]; then
    echo "[ERROR] AWS monitoring SSH key not found: $AWS_MONITORING_KEY"
    exit 1
  fi

  if is_running; then
    echo "[OK] Cloud monitoring UI tunnel is already running."
    echo "[INFO] Prometheus: http://${LOCAL_BIND}:${LOCAL_PROMETHEUS_PORT}"
    echo "[INFO] Grafana:    http://${LOCAL_BIND}:${LOCAL_GRAFANA_PORT}"
    exit 0
  fi

  rm -f "$SOCKET"

  echo "[INFO] Starting background cloud monitoring UI tunnel..."
  echo "[INFO] AWS monitoring EC2: ${AWS_MONITORING_USER}@${AWS_MONITORING_HOST}"
  echo "[INFO] Prometheus: ${LOCAL_BIND}:${LOCAL_PROMETHEUS_PORT} -> ${REMOTE_PROMETHEUS_HOST}:${REMOTE_PROMETHEUS_PORT}"
  echo "[INFO] Grafana:    ${LOCAL_BIND}:${LOCAL_GRAFANA_PORT} -> ${REMOTE_GRAFANA_HOST}:${REMOTE_GRAFANA_PORT}"

  ssh \
    -i "$AWS_MONITORING_KEY" \
    -M -S "$SOCKET" \
    -f -N -T \
    -o BatchMode=yes \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -o TCPKeepAlive=yes \
    -o StrictHostKeyChecking=accept-new \
    -L "${LOCAL_BIND}:${LOCAL_PROMETHEUS_PORT}:${REMOTE_PROMETHEUS_HOST}:${REMOTE_PROMETHEUS_PORT}" \
    -L "${LOCAL_BIND}:${LOCAL_GRAFANA_PORT}:${REMOTE_GRAFANA_HOST}:${REMOTE_GRAFANA_PORT}" \
    "$AWS_MONITORING_USER@$AWS_MONITORING_HOST"

  sleep 1

  if is_running; then
    echo "[OK] Cloud monitoring UI tunnel started."
    echo
    echo "Open:"
    echo "  Prometheus: http://${LOCAL_BIND}:${LOCAL_PROMETHEUS_PORT}"
    echo "  Grafana:    http://${LOCAL_BIND}:${LOCAL_GRAFANA_PORT}"
  else
    echo "[ERROR] Tunnel did not start correctly."
    exit 1
  fi

  echo
  echo "[INFO] Quick checks:"
  curl -fsS "http://${LOCAL_BIND}:${LOCAL_PROMETHEUS_PORT}/-/ready" && echo "  [OK] Prometheus ready" || echo "  [WARN] Prometheus not ready"
  curl -sI "http://${LOCAL_BIND}:${LOCAL_GRAFANA_PORT}/login" | head -n 1 || true
}

stop_tunnel() {
  if is_running; then
    echo "[INFO] Stopping cloud monitoring UI tunnel..."
    ssh_base -O exit >/dev/null 2>&1 || true
    rm -f "$SOCKET"
    echo "[OK] Tunnel stopped."
  else
    echo "[INFO] Tunnel is not running."
    rm -f "$SOCKET"
  fi
}

status_tunnel() {
  if is_running; then
    echo "[OK] Cloud monitoring UI tunnel is running."
    echo "Prometheus: http://${LOCAL_BIND}:${LOCAL_PROMETHEUS_PORT}"
    echo "Grafana:    http://${LOCAL_BIND}:${LOCAL_GRAFANA_PORT}"
    echo
    ss -ltn | grep -E ":(${LOCAL_PROMETHEUS_PORT}|${LOCAL_GRAFANA_PORT}) " || true
  else
    echo "[INFO] Cloud monitoring UI tunnel is not running."
    exit 1
  fi
}

case "$ACTION" in
  start)
    start_tunnel
    ;;
  stop)
    stop_tunnel
    ;;
  restart)
    stop_tunnel || true
    start_tunnel
    ;;
  status)
    status_tunnel
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
