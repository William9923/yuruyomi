#!/usr/bin/env bash

export YURUYOMI_SERVER_COMMAND_OVERRIDE="$(which cargo) run --manifest-path backend/Cargo.toml -p server -- $(pwd)"
if [[ "$1" == "--debug" ]]; then
  export YURUYOMI_SERVER_COMMAND_OVERRIDE="$(which cargo) debugger --manifest-path backend/Cargo.toml -p server -- $(pwd)"
fi

export YURUYOMI_SERVER_WORKING_DIRECTORY="$(pwd)"
[ -z "${YURUYOMI_SERVER_STARTUP_TIMEOUT+x}" ] && export YURUYOMI_SERVER_STARTUP_TIMEOUT="600"

export YURUYOMI_UDS_HTTP_REQUEST_COMMAND_OVERRIDE="$(which cargo) run --manifest-path backend/Cargo.toml -p uds_http_request --"
export YURUYOMI_UDS_HTTP_REQUEST_WORKING_DIRECTORY="$(pwd)"

exec nix run .#koreader-with-plugin -- "$HOME"
