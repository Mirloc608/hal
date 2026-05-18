#!/bin/bash

echo "Resetting runtime only (NOT dev)..."

docker stack rm hal || true
sleep 10

echo "Runtime cleared."
