---
name: OVH instance recreation
description: How to recreate the OVH agdb-cloud production instance from snapshot
---

**Current instance:** a99a85a1-07d0-4c4f-b51e-d0fae9e29472 (b3-8-flex, RBX-A)
**Snapshot:** e50514a5-6840-408b-9eb9-309d67ff0a76 (agdb-backup-before-ssh-fix, minDisk=50GB)
**IP:** 91.134.72.253 (preserved automatically by OVH from the old instance)
**SSH key name in OVH:** agdb-deploy-current (ID: 5957646b5969316b5a58427362336b7459335679636d567564413d3d)

**Why b3-8-flex and not d2-2:**
The snapshot has minDisk=50GB. d2-2 only has 25GB disk → creation fails.
Flex flavors have a fixed 50GB disk → matches snapshot minimum.
b3-8-flex: 8GB RAM, 2 vCPU, 50GB SSD, RBX-A. flavor ID: 96ac447b-734a-435a-bb5b-d36209b41fb2

**Recreation steps (via OVH CA API):**
1. Delete/add SSH key in project to update public key value
2. DELETE old instance
3. POST /cloud/project/{id}/instance with flavorId=96ac447b, imageId=e50514a5, sshKeyId=new_id
4. Poll until ACTIVE (~30s), IP 91.134.72.253 is reassigned automatically
5. ssh-keygen -R 91.134.72.253 (clear stale host key)
6. bash deploy.sh

**VNC keyboard injection does NOT work** for adding SSH keys to a running instance — ubuntu login is password-locked on OVH cloud images. Instance recreation is the only reliable path.
