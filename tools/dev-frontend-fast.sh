#!/usr/bin/env bash

# Ultra-fast frontend development - uses system KOReader with plugin symlink
# Usage: dev-frontend-fast [--no-server-check]

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
      echo "Usage: dev-frontend-fast [--no-server-check]"
      exit 1
      ;;
  esac
done

WORKING_DIR="$(pwd)"
echo "Starting yuruyomi frontend (fast mode) from: $WORKING_DIR"

# Check if backend is running (unless disabled)
if [[ "$CHECK_SERVER" == "1" ]]; then
  echo "Checking if backend server is running..."
  if ! ls /tmp/yuruyomi.sock > /dev/null 2>&1; then
    echo "❌ Backend server not detected (/tmp/yuruyomi.sock not found)"
    echo ""
    echo "Please start the backend first with:"
    echo "  dev-backend"
    echo ""
    echo "Or skip this check with:"
    echo "  dev-frontend-fast --no-server-check"
    exit 1
  fi

  # Quick health check
  if command -v curl > /dev/null 2>&1; then
    if curl --unix-socket /tmp/yuruyomi.sock http://localhost/health-check -s > /dev/null 2>&1; then
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
export YURUYOMI_SERVER_COMMAND_OVERRIDE="echo 'Using external backend server'"
export YURUYOMI_SERVER_WORKING_DIRECTORY="$WORKING_DIR"
export YURUYOMI_UDS_HTTP_REQUEST_COMMAND_OVERRIDE="$(which cargo) run --manifest-path backend/Cargo.toml -p uds_http_request --"
export YURUYOMI_UDS_HTTP_REQUEST_WORKING_DIRECTORY="$WORKING_DIR"

# Use system KOReader if available, otherwise fall back to nix
if command -v koreader > /dev/null 2>&1; then
    echo "Using system KOReader with plugin from source..."

    # Create temp plugin directory
    TEMP_PLUGIN_DIR=$(mktemp -d)
    cp -r frontend/yuruyomi.koplugin "$TEMP_PLUGIN_DIR/"

    echo "Starting KOReader with temporary plugin directory: $TEMP_PLUGIN_DIR"
    exec koreader --plugins="$TEMP_PLUGIN_DIR" "$HOME"
else
    echo "System KOReader not found, falling back to nix version..."
    exec nix run .#koreader-with-plugin-dev -- "$HOME"
fi
