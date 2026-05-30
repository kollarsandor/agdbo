---
name: Zig 0.14 build fixes
description: Recurring compile errors when building this codebase with Zig 0.14.0 and their fixes
---

## Rules

1. `@atomicFence(.seq_cst)` → `asm volatile ("mfence" ::: "memory")` (x86_64 only)
2. `@atomicFence(.acquire)` / `.release` → `asm volatile ("" ::: "memory")` (compiler fence, x86 TSO is sufficient)
3. `kv.delete()` returns `!bool` not `!void` — use `_ = kv.delete(key) catch false;` to discard
4. `std.time.nanoTimestamp()` returns `i128`, struct fields storing it are `i64` — use `@intCast()`
5. `json.getField()` returns `?Value` (not `?*Value`) — capture as `|v|` and use `v` not `v.*`
6. If a `*Database` pointer is passed to a function, don't take `&db` again — pass `db` directly

**Why:** Zig 0.14.0 removed several builtins and tightened type checking significantly.

**Zig 0.14.0 binary:** /tmp/zig-linux-x86_64-0.14.0/zig (not in PATH by default — export PATH)
