#!/usr/bin/env bash

# Start only KOReader with the rakuyomi plugin
# Usage: dev-frontend [--no-server-check]

set -e

CHECK_SERVER="1"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --no-server-check)
      CHECK_SERVER=""
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: dev-frontend [--no-server-check]"
      exit 1
      ;;
  esac
done

WORKING_DIR="$(pwd)"
echo "Starting rakuyomi frontend from: $WORKING_DIR"

# Check if backend is running (unless disabled)
if [[ "$CHECK_SERVER" == "1" ]]; then
  echo "Checking if backend server is running..."
  if ! ls /tmp/rakuyomi.sock > /dev/null 2>&1; then
    echo "❌ Backend server not detected (/tmp/rakuyomi.sock not found)"
    echo ""
    echo "Please start the backend first with:"
    echo "  dev-backend"
    echo ""
    echo "Or skip this check with:"
    echo "  dev-frontend --no-server-check"
    exit 1
  fi

  # Quick health check
  if command -v curl > /dev/null 2>&1; then
    if curl --unix-socket /tmp/rakuyomi.sock http://localhost/health-check -s > /dev/null 2>&1; then
      echo "✅ Backend server is responding"
    else
      echo "⚠️  Backend socket exists but server might not be ready"
      echo "   Starting frontend anyway..."
    fi
  else
    echo "✅ Backend socket detected"
  fi
fi

# Set environment variables for frontend
export RAKUYOMI_SERVER_COMMAND_OVERRIDE="echo 'Using external backend server'"
export RAKUYOMI_SERVER_WORKING_DIRECTORY="$WORKING_DIR"
export RAKUYOMI_UDS_HTTP_REQUEST_COMMAND_OVERRIDE="$(which cargo) run --manifest-path backend/Cargo.toml -p uds_http_request --"
export RAKUYOMI_UDS_HTTP_REQUEST_WORKING_DIRECTORY="$WORKING_DIR"

echo "Starting KOReader with rakuyomi plugin..."
exec nix run .#rakuyomi.koreader-with-plugin -- "$HOME"
