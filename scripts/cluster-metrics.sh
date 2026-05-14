#!/usr/bin/env bash
set -euo pipefail

HOST="ai-srv"
REMOTE_DIR="/opt/hal/docker/ai-srv/monitoring"

COMPOSE_YML='
version: "3.8"
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: hal-prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
  grafana:
    image: grafana/grafana:latest
    container_name: hal-grafana
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
'

PROM_YML='
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: "hal-nodes"
    static_configs:
      - targets: ["ai-srv:8000","ai-srv-node1:8000","ai-srv-node2:8000"]
'

ssh "hal@$HOST" "mkdir -p $REMOTE_DIR"

echo "$COMPOSE_YML" | ssh "hal@$HOST" "cat > $REMOTE_DIR/docker-compose.yml"
echo "$PROM_YML"    | ssh "hal@$HOST" "cat > $REMOTE_DIR/prometheus.yml"

ssh "hal@$HOST" "cd $REMOTE_DIR && docker compose up -d"

echo "Metrics: http://$HOST:3000 (Grafana), http://$HOST:9090 (Prometheus)"
