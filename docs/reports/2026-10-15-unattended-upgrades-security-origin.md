# 2026-10-15 unattended-upgrades not installing Debian security updates

## Issue

The `base` ansible role writes `/etc/apt/apt.conf.d/50unattended-upgrades`
(template `ansible/roles/base/templates/apt-unattended-upgrades`).
Its only allowed origin was:

```
origin=Debian,codename=<distribution_release>,label=Debian-Security
```

Since Debian 11 (bullseye), the security archive is published with
codename `<release>-security` (e.g. `bookworm-security`, `trixie-security`),
so this pattern matches no origin on bullseye and later:
unattended-upgrades was running every day but **never installed security updates**.

## How to check on a host

```bash
apt-cache policy | grep -i security
```

shows the security origin, e.g.
`release v=12,o=Debian,a=stable-security,n=bookworm-security,l=Debian-Security,c=main`
(note `n=bookworm-security`).

```bash
unattended-upgrade --dry-run -d 2>&1 | grep -iE "allowed origins|security|Packages that will be upgraded|No packages found"
```

Before the fix, "Allowed origins" only lists `codename=bookworm` and pending
security packages are reported as not from an allowed origin
(and "No packages found that can be upgraded unattended").
After the fix, "Allowed origins" also lists `codename=bookworm-security`
and pending security packages appear in "Packages that will be upgraded".

## Fix

`base__unattended_origins_patterns` now defaults to the same patterns as
Debian's own `50unattended-upgrades`, using the `${distro_codename}` macro
expanded by unattended-upgrades on the host (so it stays correct after a dist-upgrade):

```
origin=Debian,codename=${distro_codename},label=Debian-Security
origin=Debian,codename=${distro_codename}-security,label=Debian-Security
```

It can be overridden with `base_unattended_origins_patterns` in host_vars / group_vars
(no host currently overrides it).

## Action needed

The fix only takes effect once the `base` role is re-applied to each host
(e.g. running the host's playbook with `--tags apt`, with `--check --diff` first).
After that, verify with the `unattended-upgrade --dry-run -d` command above,
and consider running `unattended-upgrade -v` (or a manual `apt upgrade`)
to catch up on the security updates that were missed.

## Related fixes in the same role defaults

* `base__unattended_random_sleep` was set to the literal string `base_unattended_random_sleep`,
  so every host got an invalid `APT::Periodic::RandomSleep "base_unattended_random_sleep";`
  in `/etc/apt/apt.conf.d/20auto-upgrades`. It now defaults to unset (apt default of 1800s),
  and can be set with `base_unattended_random_sleep`.
* `base__timezone` referenced itself. It is now set from `base_timezone` (default `UTC`),
  and `group_vars/all/base.yml` sets `base_timezone: Europe/Paris` (same value as before).
