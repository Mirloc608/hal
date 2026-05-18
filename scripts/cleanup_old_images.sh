#!/bin/bash

echo "Pruning old HAL images..."
docker image prune -af

echo "Pruning unused build cache..."
docker builder prune -af

echo "Done."
