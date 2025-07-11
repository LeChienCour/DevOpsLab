#!/bin/sh

DOCKERFILE="../backend/Dockerfile"

echo "Checking for multi-stage build..."
grep -q "AS development" "$DOCKERFILE" && \
grep -q "AS production" "$DOCKERFILE" || { echo "❌ Missing required stages"; exit 1; }

echo "Checking for npm ci in production..."
grep -q "npm ci" "$DOCKERFILE" || { echo "❌ Missing 'npm ci' in production"; exit 1; }

echo "Checking for HEALTHCHECK..."
grep -qi "HEALTHCHECK" "$DOCKERFILE" || { echo "❌ Missing HEALTHCHECK"; exit 1; }

echo "Checking for /app/logs directory creation..."
grep -q "mkdir -p /app/logs" "$DOCKERFILE" || { echo "❌ Missing logs directory creation"; exit 1; }

echo "✅ Challenge 2 Dockerfile passes basic checks!"
exit 0 