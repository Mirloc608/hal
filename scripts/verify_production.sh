#!/bin/bash

echo "============================="
echo " HAL PRODUCTION VERIFICATION"
echo "============================="

ENDPOINTS=(
  "http://localhost:7200/health"
  "http://localhost:9000/health"
  "http://localhost:9100/health"
  "http://localhost:9200/health"
)

for url in "${ENDPOINTS[@]}"; do
  echo "Checking $url"

  if curl -s "$url" > /dev/null; then
    echo "[OK] $url"
  else
    echo "[FAIL] $url"
    exit 1
  fi
done

echo "ALL SYSTEMS GREEN"
