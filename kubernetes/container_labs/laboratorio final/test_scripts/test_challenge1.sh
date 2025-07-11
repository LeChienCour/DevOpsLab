#!/bin/sh

DOCKERFILE="../frontend/Dockerfile"

echo "Checking for 3 stages (development, build, production)..."
grep -q "AS development" "$DOCKERFILE" && \
grep -q "AS build" "$DOCKERFILE" && \
grep -q "AS production" "$DOCKERFILE" || { echo "❌ Missing required stages"; exit 1; }

echo "Checking for Vite build step..."
grep -q "npm run build" "$DOCKERFILE" || { echo "❌ Missing Vite build step"; exit 1; }

echo "Checking for Nginx in production stage..."
grep -q "FROM nginx:alpine" "$DOCKERFILE" || { echo "❌ Missing Nginx production stage"; exit 1; }

echo "Checking for HEALTHCHECK..."
grep -qi "HEALTHCHECK" "$DOCKERFILE" || { echo "❌ Missing HEALTHCHECK"; exit 1; }

echo "✅ Challenge 1 Dockerfile passes basic checks!"
exit 0 