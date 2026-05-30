---
name: SSH key persistence
description: How the deploy SSH key is stored persistently across Replit restarts
---

~/.ssh/id_ed25519 is wiped every time the Replit container restarts.

**Fix:** The private key is saved to `.deploy_key` in the project root (gitignored). deploy.sh detects this file and uses it automatically:

```bash
SCRIPT_DIR_EARLY="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${SCRIPT_DIR_EARLY}/.deploy_key" ]; then
  SSH_KEY="${SCRIPT_DIR_EARLY}/.deploy_key"
else
  SSH_KEY="${OVH_SSH_KEY:-$HOME/.ssh/id_ed25519}"
fi
```

**If .deploy_key is lost (e.g. git clone on a new machine):**
1. `ssh-keygen -t ed25519 -f .deploy_key -N ""`
2. Update the `agdb-deploy-current` key in OVH: delete old, POST new pubkey
3. Recreate the OVH instance from snapshot with new key (see ovh-instance-recreation.md)
4. `bash deploy.sh`

**Current public key fingerprint:** SHA256:zxDGCu324g23rKx0RRAj+UZSslNrUGAwzI5KdIOcFqA

**Why:** Replit ephemeral containers don't persist ~/.ssh. The project directory IS persistent.
