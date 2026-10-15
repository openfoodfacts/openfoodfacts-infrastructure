# 2026-10-15 Product Opener containers: in-place Debian → trixie upgrade

Simpler alternative to
[2026-10-05-opff-debian-bullseye-to-trixie-upgrade.md](./2026-10-05-opff-debian-bullseye-to-trixie-upgrade.md):
no blue/green container, no cloned data volumes, no dataset swap.
The container is upgraded **in place**, during a short maintenance window,
with a **ZFS snapshot of the rootfs** as the rollback.

## Why this is reasonably safe

* **The application stack is already validated on trixie**: staging and dev run
  Product Opener from the `Dockerfile` (`FROM debian:trixie-slim`), i.e. perl 5.40,
  ImageMagick 7, tesseract 5, apache 2.4 + mod_perl, and the same `cpanfile`
  (pinned `MongoDB 2.2.x` talking to the MongoDB 4.4 server, `Type::Tiny::XS 0.025`, …).
  What remains specific to production is the host config, not the code.
* **The data is not in the rootfs**: products, images, users, orgs, html_data, cache
  are separate ZFS datasets mounted into the container (`mp0`…`mp6`).
  The upgrade only touches the rootfs, so rolling back the rootfs never loses data.
* **Rollback is one command** (`zfs rollback`) and takes seconds.
* **scaleway-01 runs proxmox-ve 9.2**, which knows Debian 13 (the trap that bit
  matomo on ovh2 does not apply).

## Containers and order

All on `scaleway-01`, all clones of the same rootfs, so the first one teaches us
everything about the others:

| Order | CT | Hostname | Site |
| --- | --- | --- | --- |
| 1 (canary) | 115 | `opff` | openpetfoodfacts.org |
| 2 | 114 | `opf` | openproductsfacts.org |
| 3 | 113 | `obf` | openbeautyfacts.org |
| 4 | 112 | `off-pro` | pro.openfoodfacts.org |
| 5 | 111 | `off` | openfoodfacts.org (own window, after a few quiet days) |

Write down in the [Log](#log) every surprise met on opff (prompts, clobbered
configs, failed modules): the following containers then become mechanical.

**Check the starting release first**: the 2026-10-05 inventory says
`11.10 (bullseye)`. If `cat /etc/debian_version` says `10.x` (buster), add one
hop (buster → bullseye) with `archive.debian.org` sources, same procedure.

## What changes compared to the 2026-10-05 plan

| 2026-10-05 plan | This plan |
| --- | --- |
| clone CT 117 + `-trixie` clones of 5 data datasets, new IP, hostname hacks | nothing: work on the real container |
| make the site work on bookworm (cpanm rebuild on perl 5.36), then again on trixie | bookworm is only a transit step, site stays stopped; perl modules are rebuilt **once**, on trixie |
| `cpanm` sequential reinstall | `cpm` in parallel, exactly like the `Dockerfile` (minutes, not an hour) |
| apt packages discovered by hand | the apt package list is taken from the `Dockerfile` that staging already runs |
| dataset rename cutover + rename rollback | `zfs rollback` of one snapshot |

The cost: the site is down for the whole window (estimate 45–90 min for opff,
mostly apt downloads/unpacking), instead of ~5 min. For opff/opf/obf this is an
acceptable trade-off; for off, measure it on the first ones before deciding.

## Procedure (example: opff, CT 115)

### 0. Before the window (site still up, read only)

```bash
# in the container
cat /etc/debian_version
dpkg-query -W -f='${binary:Package}\t${Version}\n' | sort > /root/dpkg-before.tsv
apt-mark showmanual | sort > /root/apt-manual-before.txt
systemctl list-units --failed --no-pager > /root/failed-before.txt   # known: gen_feeds_daily, networking
systemctl list-unit-files --state=enabled --no-pager > /root/enabled-before.txt
ls -l /etc/apache2/ports.conf /etc/apache2/sites-enabled/ /etc/nginx/mime.types \
      /etc/nginx/sites-enabled/ /etc/nginx/snippets/ /etc/systemd/system/*.d/ \
  > /root/conf-symlinks-before.txt
git -C /srv/opff log -1 --format='%H %s' > /root/git-before.txt

# bring the current release fully up to date (normal maintenance; apache and nginx
# get restarted a few times, a few seconds each)
apt update && apt full-upgrade
```

Silence the monitoring alerts for the container for the duration of the window.

**Run the whole window inside `tmux` on scaleway-01** (`tmux new -s trixie`, then
`pct enter 115`): it lasts 45–90 min, and a dropped SSH session in the middle of
dpkg is the one thing that turns this into a recovery.

```bash
# on scaleway-01: enough room in the 30G rootfs quota?
zfs get quota,refquota,used,available zfs-hdd/pve/subvol-115-disk-0
```

If less than ~6G is available, raise it first (`pct resize 115 rootfs 40G`).

### 1. Stop the site and snapshot the rootfs

```bash
# in the container
systemctl list-timers --all --no-pager | grep -E 'opff|apt'   # stop every opff timer listed
systemctl stop apache2 nginx minion@opff redis_listener@opff cloud_vision_ocr@opff \
               gen_feeds_daily@opff.timer gen_feeds@opff.timer cron
# disabled (not only stopped), otherwise they start again at the step 5 reboot,
# before validation, with Automatic-Reboot "true"
systemctl disable --now unattended-upgrades apt-daily.timer apt-daily-upgrade.timer

# package upgrades restart enabled services even if they are stopped: apache would
# then come back with mod_perl and no rebuilt CPAN modules, and a failing restart
# can make the postinst fail and stop the full-upgrade. Forbid any service start
# until step 5.
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d
```

```bash
# on scaleway-01 — the rollback point (non-autosnap name, so sanoid keeps it)
SNAP=pre-trixie_$(date --utc +%Y-%m-%d_%H%M)
zfs snapshot zfs-hdd/pve/subvol-115-disk-0@$SNAP
echo $SNAP
```

During the window, put up the maintenance page on `scaleway-proxy` if we have
one, otherwise the proxy will just answer 502.

### 2. bullseye → bookworm (transit only)

```bash
mkdir -p /root/apt-old && mv /etc/apt/sources.list /etc/apt/sources.list.d/*.list /root/apt-old/
# (this also drops the mongodb-org-4.4 repo: no bookworm/trixie build, and we stay on 4.4 server side)

cat > /etc/apt/sources.list.d/debian.sources <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: bookworm bookworm-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://deb.debian.org/debian-security
Suites: bookworm-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

# set again in any new shell (step 3 included), or the prompts come back
export DEBIAN_FRONTEND=noninteractive UCF_FORCE_CONFFOLD=1
APT_OPTS='-o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef'
apt update
apt $APT_OPTS upgrade --without-new-pkgs -y
apt $APT_OPTS full-upgrade -y
```

`--force-confold` (and `UCF_FORCE_CONFFOLD` for the files managed by `ucf`) keeps
our versions of every modified config file (apache,
nginx, fail2ban, sudoers…) instead of prompting; the `*.dpkg-dist` files it leaves
are reviewed at step 5. No reboot, no perl rebuild, no test here: the site stays
down and we go straight on.

### 3. bookworm → trixie

```bash
# in case this is a new shell
export DEBIAN_FRONTEND=noninteractive UCF_FORCE_CONFFOLD=1
APT_OPTS='-o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef'

sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/debian.sources
apt update
apt $APT_OPTS upgrade --without-new-pkgs -y
apt $APT_OPTS full-upgrade -y
apt autoremove --purge          # read the list before confirming
apt purge mongodb-database-tools   # leftover from the 4.4 repo, dumps are done on the MongoDB host
```

### 4. Rebuild the perl dependencies, the way staging does

The old CPAN modules live in `/usr/local/share/perl/5.32.1` and
`/usr/local/lib/x86_64-linux-gnu/perl/5.32.1`: perl 5.40 simply does not look
there anymore, so there is nothing to remove now (delete them at cleanup).

```bash
# apt packages: exactly the list the Dockerfile installs (modperl stage)
cd /srv/opff
PKGS=$(perl -ne 'last if /^FROM modperl AS builder/; $in=1 if /apt-get install/;
  if ($in) { print "$1\n" if /^\s+([a-z0-9][a-z0-9.+-]+)\s*\\?\s*$/; $in=0 if !/\\\s*$/ && !/^\s*#/ }' Dockerfile | sort -u)
echo $PKGS
apt install -y --no-install-recommends $PKGS

# cpm, same pinned commit and checksum as the Dockerfile of main: the deployed
# release (2.109.0) predates the pinning and fetches cpm from its main branch,
# so the values are read from origin/main, not from the checked-out Dockerfile
sudo -u off git fetch origin main
CPM_COMMIT=$(sudo -u off git show origin/main:Dockerfile | sed -n 's/^ARG CPM_COMMIT=//p')
CPM_SHA256=$(sudo -u off git show origin/main:Dockerfile | sed -n 's/^ARG CPM_SHA256=//p')
[ -n "$CPM_COMMIT" ] && [ -n "$CPM_SHA256" ] || echo "cpm pin not found, stop here"
curl -fsSL "https://raw.githubusercontent.com/skaji/cpm/${CPM_COMMIT}/cpm" -o /usr/local/bin/cpm
echo "${CPM_SHA256}  /usr/local/bin/cpm" | sha256sum -c && chmod +x /usr/local/bin/cpm

# global install into /usr/local/{share,lib}/perl/5.40.x, like before
cpm install --show-build-log-on-failure -w $(nproc) -g Apache::Bootstrap
cpm install --show-build-log-on-failure -w $(nproc) -g 2>&1 | tee /root/cpm-trixie.log
grep -E '^FAIL' /root/cpm-trixie.log      # must be empty, or understood

# smoke test the modules that matter
# (Apache2::* modules and the cgi scripts only load inside mod_perl, they are
# tested by apache starting in step 5, not here)
for m in MongoDB Imager Imager::zxing Image::Magick Minion Mojolicious OIDC::Lite GeoIP2 \
         GS1::SyntaxEngine::FFI; do
  sudo -u off perl -M$m -e "print qq{$m ok\n}" 2>&1 | tail -1
done
```

### 5. Restore config, start, check

```bash
# configs that dpkg may have replaced: compare with step 0
ls -l /etc/apache2/ports.conf /etc/apache2/sites-enabled/ /etc/nginx/mime.types \
      /etc/nginx/sites-enabled/ /etc/nginx/snippets/ /etc/systemd/system/*.d/ \
  | diff /root/conf-symlinks-before.txt - 
find /etc -name '*.dpkg-dist' -o -name '*.dpkg-new' -o -name '*.ucf-dist'   # review, keep ours unless needed
# re-create any clobbered symlink from /srv/opff/conf/...

apache2ctl configtest && nginx -t && systemctl daemon-reload

# allow services to start again
rm /usr/sbin/policy-rc.d
```

If `nginx -t` complains about an unknown directive: trixie folded
`nginx-full`/`nginx-light` into a single `nginx` package, some modules may now be
dynamic, check `/etc/nginx/modules-enabled/`.

Then reboot the container (from scaleway-01: `pct reboot 115`) so that everything
starts like it will in normal life, and check:

```bash
cat /etc/debian_version                   # 13.x
perl -v | head -2                         # 5.40
systemctl list-units --failed --no-pager | diff /root/failed-before.txt -
systemctl list-unit-files --state=enabled --no-pager | diff /root/enabled-before.txt -
#   (apt-daily*/unattended-upgrades show up here until re-enabled below)
git -C /srv/opff log -1 --format='%H %s' | diff /root/git-before.txt -
git -C /srv/opff status --short           # only the known untracked entries
curl -sS -o /dev/null -w '%{http_code} %{time_total}s\n' -H 'Host: world.openpetfoodfacts.org' http://127.0.0.1/
curl -sS -o /dev/null -w '%{http_code} %{time_total}s\n' -H 'Host: world.openpetfoodfacts.org' http://127.0.0.1/api/v2/product/3017620422002
journalctl -u apache2 -u minion@opff -p warning -b --no-pager | tail -50
tail -50 /srv/opff/logs/*.log /var/log/apache2/error.log
```

From outside, on <https://world.openpetfoodfacts.org>: front page, search, a
product page, product images (ImageMagick 7), login, **one product edit** and **one
image upload** (minion processes it), the API. Then re-enable the timers
and the monitoring alerts:

```bash
systemctl enable --now unattended-upgrades apt-daily.timer apt-daily-upgrade.timer
```

### Rollback (any time, seconds)

```bash
# on scaleway-01
pct stop 115
zfs rollback -r zfs-hdd/pve/subvol-115-disk-0@pre-trixie_<date>
pct start 115
```

`-r` drops the sanoid snapshots taken after ours (they only contain the half-done
upgrade). Data datasets are untouched, so writes made after the window (edits,
uploads) are kept. Low risk: files written meanwhile by perl 5.40 (e.g. newer
Storable `.sto` files) are then read by perl 5.32; look at the error log after a
late rollback.

`zfs-hdd/pve` is pulled with `--no-sync-snap` by hetzner-01 and scaleway-03:
syncoid should roll their copies back to the last common snapshot by itself,
check its next run (`systemctl status syncoid` on those hosts).

### Cleanup (a week later)

```bash
# in the container
rm -rf /usr/local/share/perl/5.32.1 /usr/local/lib/x86_64-linux-gnu/perl/5.32.1 /root/apt-old
# on scaleway-01
zfs destroy zfs-hdd/pve/subvol-115-disk-0@pre-trixie_<date>
```

## Known points to watch

* **ImageMagick 6 → 7**: validated by staging for the perl binding; check the
  shell scripts that call `convert` directly still work (IM7 keeps `convert` as a
  compatibility command).
* **nginx geoip modules** (`libnginx-mod-http-geoip`): `nginx -t` tells us if a
  `geoip_*` directive lost its module.
* **mod_perl startup**: `conf/apache-2.4` is the production config, not the one
  staging uses (docker); this is the most likely place for a surprise — read
  `/var/log/apache2/error.log` first if apache does not answer.
* `gen_feeds_daily@opff` was **already failing** before the upgrade
  (`export_database.pl`), don't count it as a regression.

## Log

<!-- to be filled while doing the work, one section per container -->
