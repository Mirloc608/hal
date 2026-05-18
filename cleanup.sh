#!/bin/bash

echo "Stopping HAL services..."

pkill -f uvicorn

echo "Cleaning temporary runtime state..."

rm -rf /tmp/hal_cache/*

echo "HAL cleanup complete."
