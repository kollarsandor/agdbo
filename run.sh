#!/usr/bin/env bash
set -euo pipefail

ZIG_VERSION="0.14.0"
ZIG_DIR="/tmp/zig-linux-x86_64-${ZIG_VERSION}"
ZIG="${ZIG_DIR}/zig"

if [ -f "./zig" ]; then
  ZIG="./zig"
  ZIG_DIR="$(dirname "$ZIG")"
elif [ ! -f "$ZIG" ]; then
  echo "==> Downloading Zig ${ZIG_VERSION}..."
  curl -sL "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" \
    -o "/tmp/zig-${ZIG_VERSION}.tar.xz"
  tar -xf "/tmp/zig-${ZIG_VERSION}.tar.xz" -C /tmp/
  echo "==> Zig ${ZIG_VERSION} ready."
fi

export PATH="${ZIG_DIR}:$PATH"

echo "==> Syncing frontend..."
cp index.html src/cloud/index.html

echo "==> Building agdb-cloud (Debug)..."
"$ZIG" build -Doptimize=Debug \
  "-DAGDB_REGISTRY_PATH=/tmp/agdb/registry.agdb" \
  "-DAGDB_DATA_ROOT=/tmp/agdb/tenants"

mkdir -p /tmp/agdb/tenants

echo "==> Starting agdb-cloud on port 5000..."
exec env \
  AGDB_CLOUD_PORT=5000 \
  AGDB_REGISTRY_PATH=/tmp/agdb/registry.agdb \
  AGDB_DATA_ROOT=/tmp/agdb/tenants \
  ./zig-out/bin/agdb-cloud
