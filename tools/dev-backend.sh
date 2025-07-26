#!/usr/bin/env bash

# Start only the Rust backend server
# Usage: dev-backend [--debug] [--tcp]

set -e

ARGS=()
ENABLE_TCP=""
DEBUG_MODE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --debug)
      DEBUG_MODE="1"
      shift
      ;;
    --tcp)
      ENABLE_TCP="1"
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

# Set working directory
WORKING_DIR="$(pwd)"
echo "Starting yuruyomi backend from: $WORKING_DIR"

# Set environment variables
export YURUYOMI_SERVER_WORKING_DIRECTORY="$WORKING_DIR"
export RUST_LOG="${RUST_LOG:-info}"

# Enable TCP if requested
if [[ "$ENABLE_TCP" == "1" ]]; then

  export YURUYOMI_ENABLE_TCP=1
  echo "TCP endpoint enabled on http://127.0.0.1:8080"
fi

# Choose command based on debug mode
if [[ "$DEBUG_MODE" == "1" ]]; then
  echo "Starting backend in debug mode..."
  COMMAND="$(which cargo) debugger --manifest-path backend/Cargo.toml -p server -- $WORKING_DIR"
else
  echo "Starting backend..."
  COMMAND="$(which cargo) run --manifest-path backend/Cargo.toml -p server -- $WORKING_DIR"
fi

echo "Executing: $COMMAND"
exec $COMMAND
