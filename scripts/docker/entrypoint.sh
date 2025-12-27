#!/bin/sh
set -e

echo "Sleeping 5s to let blockchain start..."
sleep 5

echo "Running deployment..."
node scripts/deploy.js

tail -f /dev/null
