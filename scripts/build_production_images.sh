#!/bin/bash

set -e

echo "============================="
echo " HAL PRODUCTION BUILD PIPELINE"
echo "============================="

cd /srv/hal

echo "[1] Copying validated dev code → runtime staging"
rsync -av --delete /opt/hal/ /srv/hal/

echo "[2] Building images"

docker build -t 192.168.1.250:5000/hal-gateway:latest /srv/hal
docker build -t 192.168.1.250:5000/hal-ps:latest /srv/hal
docker build -t 192.168.1.250:5000/hal-mesh:latest /srv/hal
docker build -t 192.168.1.250:5000/hal-rag:latest /srv/hal
docker build -t 192.168.1.250:5000/hal-ppo-actor:latest /srv/hal
docker build -t 192.168.1.250:5000/hal-ppo-learner:latest /srv/hal
docker build -t 192.168.1.250:5000/hal-gpu:latest /srv/hal

echo "[3] Pushing images"
docker push 192.168.1.250:5000/hal-gateway:latest
docker push 192.168.1.250:5000/hal-ps:latest
docker push 192.168.1.250:5000/hal-mesh:latest
docker push 192.168.1.250:5000/hal-rag:latest
docker push 192.168.1.250:5000/hal-ppo-actor:latest
docker push 192.168.1.250:5000/hal-ppo-learner:latest
docker push 192.168.1.250:5000/hal-gpu:latest

echo "BUILD COMPLETE"
