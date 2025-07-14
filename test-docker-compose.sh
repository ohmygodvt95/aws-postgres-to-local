#!/bin/bash

# Test script for Docker Compose detection

echo "Testing Docker Compose detection..."
echo "=================================="

# Test docker compose (v2)
if docker compose version >/dev/null 2>&1; then
    echo "✓ docker compose (v2) is available:"
    docker compose version
else
    echo "✗ docker compose (v2) is not available"
fi

echo

# Test docker-compose (v1)
if command -v docker-compose >/dev/null 2>&1; then
    echo "✓ docker-compose (v1) is available:"
    docker-compose version
else
    echo "✗ docker-compose (v1) is not available"
fi

echo

# Test detection function (same as in postgres-tool.sh)
get_docker_compose_cmd() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        echo ""
    fi
}

DETECTED_CMD=$(get_docker_compose_cmd)
if [[ -n "$DETECTED_CMD" ]]; then
    echo "✓ Detected command: $DETECTED_CMD"
    echo "Testing detected command:"
    $DETECTED_CMD version
else
    echo "✗ No Docker Compose command detected"
fi
