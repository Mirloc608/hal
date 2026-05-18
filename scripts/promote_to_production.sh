#!/bin/bash

set -e

echo "===================================="
echo " HAL FULL PRODUCTION PROMOTION"
echo "===================================="

python3 /opt/hal/scripts/validate_hal.py

echo "[STEP 1] BUILD"
bash /opt/hal/scripts/build_production_images.sh

echo "[STEP 2] DEPLOY"
bash /opt/hal/scripts/deploy_production_stack.sh

echo "[STEP 3] VERIFY"
bash /opt/hal/scripts/verify_production.sh

echo "===================================="
echo " HAL IS NOW IN PRODUCTION STATE"
echo "===================================="
