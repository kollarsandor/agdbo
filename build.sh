#!/usr/bin/env bash
set -euo pipefail

# Wrapper to use the correct Zig 0.14.0 for this project
ZIG="./zig-local"
if [ ! -f "$ZIG" ]; then
    ZIG="/tmp/zig-linux-x86_64-0.14.0/zig"
fi
if [ ! -f "$ZIG" ]; then
    echo "Error: Zig 0.14.0 not found at ./zig-local or /tmp/zig-linux-x86_64-0.14.0/zig"
    echo "Run deploy.sh first to download Zig 0.14.0, or download it manually."
    exit 1
fi

# Always use the correct zig
exec "$ZIG" "$@"
