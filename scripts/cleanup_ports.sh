#!/bin/bash

echo "Stopping ALL HAL-related containers..."

docker stop $(docker ps -q --filter "name=hal") 2>/dev/null

echo "Removing HAL containers..."

docker rm $(docker ps -aq --filter "name=hal") 2>/dev/null

echo "Killing orphan processes on ports 7300-7310..."

for port in {7300..7310}; do
  pid=$(lsof -t -i:$port)
  if [ ! -z "$pid" ]; then
    echo "Killing PID $pid on port $port"
    kill -9 $pid
  fi
done

echo "Cleanup complete."
