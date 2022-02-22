# [Postmortem] OpenFoodFacts.net down (#1)

**Date**: 03/10/2021

**Authors**: ocervello, <add name here>

**Status**: Complete, action items in progress

**Summary**: openfoodfacts.net down after Docker storage driver configuration change. Proxmox containers `off-net`, `robotoff-net`, `robotoff-dev`, `mongo-dev`, and `monitoring` are unreachable.

**Impact**: Integration tests failing on openfoodfacts-dart ([example](https://github.com/openfoodfacts/openfoodfacts-dart/runs/3812250555?check_suite_focus=true)), pre-prod environment (openfoodfacts.net) down.

**Root Causes**: Cascading failure probably due to Docker storage driver configuration change from `vfs` to `fuse-overlayfs`, and ***probably*** an incompatibility between LXC, Docker and `fuse-overlayfs`, causing containers to crash, and unable to SSH. **Exact root cause is still unknown**, as some containers using `fuse-overlayfs` have not crashed.

**Trigger**: Unknown. First outage happened 3 days after the Docker storage driver change.

## Resolution


- **Short term:** revert Docker storage driver configuration from `fuse-overlayfs` to `vfs`.
- **Long term:** run Docker containers in a QEMU host instead.

**Detection**: message on Slack #infrastructure channel + openfoodfacts-dart integration tests [failing](https://github.com/openfoodfacts/openfoodfacts-dart/actions/runs/1295321901) with timeouts.

## Action Items


|**Action Item**|**Type**|**Owner**|**Status**|
| :- | :- | :- | :- |
|Revert Docker storage driver to `vfs`|mitigate|olivier|**DONE**|
|Snapshot off-net CT and start a new CT from the snapshot|mitigate|charles|**FAILED**|
|Create vanilla CT with storage driver `vfs` and re-deploy openfoodfacts.net on it + ZFS Mounts + NGINX config change|mitigate|charles,olivier,stephane,christian|**IN PROGRESS**|
|Open ticket to Proxmox forums to investigate the crash|process|charles|**TODO**|
|Run all crashed Docker containers on QEMU VM for stability + ZFS mounts + NGINX configuration|prevent|olivier,charles,stephane,christian|<https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/62>|

## Lessons Learned

### What went well

- Community + staff got quickly alerted of openfoodfacts.net being down
- Worked together to solve the issues

### What went wrong

- No explicit alert message was sent to productopener-alerts Slack channel → need integration tests on **openfoodfacts-server** repository
- Too many CTs brought down simultaneously - should have done the storage engine change on only 1 host and wait
- Proxmox container cloning failed, increasing the ETTR (Estimated Time To Repair)
- Proxmox container failed to reboot, increasing the ETTR
- Too much noise on `productopener-alerts`, failed deployments were missed.
- Sysadmins were not aware about all the impacts of off-net downtime.
- No single point to track the investigation and resolution (e.g. GitHub issue)

### Where we got lucky

- Did not bring down production as it is still running on the Free machines.
- Automated deployments allowed us to re-deploy openfoodfacts.net pretty fast
- The right people were available.

### What we learned

- Assuming the root cause is correct: Proxmox LXC + Docker + ZFS + fuse-overlayfs storage driver can trigger severe issues where even Proxmox administration tools do not work (clones, snapshots, etc…)
## Timeline

#### 29-09-2021 (All times CEST)

- 15:46 **ROOT CAUSE** — **Docker storage driver switch from `vfs` to `fuse-overlayfs`** made on all CTs w/ Docker deployments.

### 03-10-2021 (All times CEST)

- 02:17 **OUTAGE BEGINS** — Automated message on #infrastructure-alerts Slack channel about timeouts when trying to access world.openfoodfacts.net
- 19:16 **OUTAGE BEGINS** — Manual message by contributor on #infrastructure Slack channel about timeouts when trying to access world.openfoodfacts.net

### 04-10-2021 (All times CEST)

- 9:23 Message on #infrastructure Slack channel that multiple containers are unresponsive.

### 06-10-2021 (All times CEST)

- 14:36 **OUTAGE MITIGATED**, deployed openfoodfacts.net and a new machine. Mounts are still missing on disk.
- 14:45 Decision taken to switch Docker containers to QEMU VM.
- 15:36 Creation of QEMU VM 128GB RAM, 8 cores, 196GB drive.

### 07-10-2021 (All times CEST)

- 09:00 Starting to manually deploy openfoodfacts-server, robotoff, robotoff-ann and monitoring containers on QEMU VM
- 09:30 Openfoodfacts server is deployed on QEMU VM
- 10:20 Robotoff deployment is blocked by a CPU flag issue (avx flag needed for Tensorflow library)

## Supporting information:

- Document  a clear realistic “acceptable downtime” for each CT/VM/machines we manage (using the [existing spreadsheet](https://docs.google.com/spreadsheets/d/19RePmE_-1V_He73fpMJYukEMjPWNmav1610yjpGKfD0/edit#gid=0)).
- Document the main owner and his/her co-owner (?) of each machine, ie people able to restore a service within the “acceptable downtime” and owning this responsibility.
- Decide how we document the infrastructure (not well decided yet).
- Is it possible to publish only real alerts in #infrastructure-alerts? Eg, only publish alerts if the machine is down for more than 15 minutes. Most of the alerts seems to be false positives.
- Define a process to resolve future incidents (e.g. should we systematically file a github issue for each incident?)
