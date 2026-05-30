---
name: agdb-cloud binary layout
description: What binaries are built and where they go on the OVH server
---

## Build output (zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl)

- zig-out/bin/agdb-cloud          → /opt/agdb/bin/agdb-cloud (main HTTP server, port 7070)
- zig-out/usr/lib/agdb/sandbox_runner → /usr/lib/agdb/sandbox_runner (spawned per tenant)
- zig-out/bin/agdb                → CLI tool (optional)
- zig-out/bin/agdb-runtime        → runtime helper (optional)

## Server config
- OVH IP: 91.134.72.253, user: ubuntu
- nginx proxies :80 → localhost:7070
- systemd service: agdb-cloud.service
- Registry DB: /var/lib/agdb/registry.agdb
- Tenant data: /var/lib/agdb/tenants/

## Deploy
Run `./deploy.sh` from project root (requires SSH key ~/.ssh/id_ed25519 or OVH_SSH_KEY secret)

**Why:** Sandbox runner is a separate binary spawned per-tenant as an isolated child process.
