#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PROTO_FILE="$ROOT_DIR/proto/mediguide/aiworker/v1/aiworker.proto"

cd "$ROOT_DIR"

protoc \
  -I "$ROOT_DIR/proto" \
  --go_out="$ROOT_DIR/backend" \
  --go_opt=module=mediguide \
  --go-grpc_out="$ROOT_DIR/backend" \
  --go-grpc_opt=module=mediguide \
  "$PROTO_FILE"

uv run --with grpcio-tools python -m grpc_tools.protoc \
  -I "$ROOT_DIR/proto" \
  --python_out="$ROOT_DIR/ai-worker" \
  --grpc_python_out="$ROOT_DIR/ai-worker" \
  "$PROTO_FILE"
