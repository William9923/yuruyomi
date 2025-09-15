#!/usr/bin/env bash

# Start only KOReader with the yuruyomi plugin
# Usage: dev-frontend [--no-server-check]
#
# This script copies your source plugin directly to KOReader's plugins directory:
#   ~/Library/Application Support/koreader/plugins/yuruyomi.koplugin
#
# Environment variables:
#   YURUYOMI_USE_NIX_PLUGIN=1    Use Nix-built plugin (slower, but matches production)
#   (default)                    Copy source files to KOReader plugins dir (faster development)

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
echo "Starting yuruyomi frontend from: $WORKING_DIR"

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
    echo "  dev-frontend --no-server-check"
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

# Build uds_http_request if it doesn't exist
UDS_BINARY="$WORKING_DIR/backend/target/debug/uds_http_request"
if [[ ! -f "$UDS_BINARY" ]]; then
    echo "Building uds_http_request binary..."
    cd "$WORKING_DIR" && cargo build --manifest-path backend/Cargo.toml -p uds_http_request
fi

export YURUYOMI_UDS_HTTP_REQUEST_COMMAND_OVERRIDE="$UDS_BINARY"
export YURUYOMI_UDS_HTTP_REQUEST_WORKING_DIRECTORY="$WORKING_DIR"

echo "Starting KOReader with yuruyomi plugin..."
# Default to using source files for development (can be overridden)
if [[ "${YURUYOMI_USE_NIX_PLUGIN:-}" == "1" ]]; then
    echo "Using Nix-built plugin (rebuilding)..."
    nix build .#koreader-with-plugin-dev --rebuild
    exec nix run .#koreader-with-plugin-dev -- "$HOME"
else
    echo "Using source files directly for faster development..."

    # Copy source plugin to KOReader's standard plugins directory
    # Detect the correct plugins directory based on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        KOREADER_PLUGINS_DIR="$HOME/Library/Application Support/koreader/plugins"
    else
        # Linux and other Unix-like systems use XDG config directory
        if [[ -n "$XDG_CONFIG_HOME" ]]; then
            KOREADER_PLUGINS_DIR="$XDG_CONFIG_HOME/koreader/plugins"
        else
            KOREADER_PLUGINS_DIR="$HOME/.config/koreader/plugins"
        fi
    fi
    PLUGIN_NAME="yuruyomi.koplugin"

    echo "Creating KOReader plugins directory if it doesn't exist..."
    mkdir -p "$KOREADER_PLUGINS_DIR"

    echo "Copying source plugin to: $KOREADER_PLUGINS_DIR/$PLUGIN_NAME"
    # Remove existing plugin first to ensure clean copy
    rm -rf "$KOREADER_PLUGINS_DIR/$PLUGIN_NAME"
    cp -r "plugins/$PLUGIN_NAME" "$KOREADER_PLUGINS_DIR/"

    echo "Plugin copied successfully. Changes will be reflected immediately."

    # Use Nix KOReader (no need for --plugins flag now)
    exec nix run .#koreader -- "$HOME"
fi