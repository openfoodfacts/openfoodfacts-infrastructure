# 2026-10-15 Product Opener containers: in-place Debian → trixie upgrade

Simpler alternative to
[2026-10-05-opff-debian-bullseye-to-trixie-upgrade.md](./2026-10-05-opff-debian-bullseye-to-trixie-upgrade.md):
no blue/green container, no cloned data volumes, no dataset swap.
The container is upgraded **in place**, during a maintenance window,
with a **ZFS snapshot of the rootfs** as the rollback.

opff (CT 115) was done first, on 2026-10-15: see the [Log](#log). The procedure
below already includes everything learned there.

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
| 1 (canary) | 115 | `opff` | openpetfoodfacts.org — **done 2026-10-15** |
| 2 | 114 | `opf` | openproductsfacts.org |
| 3 | 113 | `obf` | openbeautyfacts.org |
| 4 | 112 | `off-pro` | pro.openfoodfacts.org |
| 5 | 111 | `off` | openfoodfacts.org (own window, after a few quiet days) |

Write down in the [Log](#log) every surprise met (prompts, clobbered configs,
failed modules): the following containers then become mechanical.

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

The cost: the site is down for the whole window, instead of ~5 min. On opff the
bullseye → bookworm hop alone took **about one hour** (most likely because dpkg fsyncs every file on `zfs-hdd`,
plus many desktop packages nobody uses, see step 0), so count **2–3 hours** of
downtime unless the speed-ups of step 0 are applied. For opff/opf/obf this is
an acceptable trade-off; for off, measure it on the others first.

Keeping the site up during `full-upgrade` is **not** an option: perl, libc,
libssl and ImageMagick are replaced under the running processes, mod_perl can no
longer load the 5.32 CPAN modules, and half-done writes would land on the data
datasets, which a rootfs rollback does not cover. A site that must stay up needs
the blue/green plan of 2026-10-05.

## Procedure (example: opff, CT 115)

### 0. Before the window (site still up)

```bash
# in the container
cat /etc/debian_version
dpkg-query -W -f='${binary:Package}\t${Version}\n' | sort > /root/dpkg-before.tsv
apt-mark showmanual | sort > /root/apt-manual-before.txt
systemctl list-units --failed --no-pager > /root/failed-before.txt   # known: gen_feeds_daily, networking, ifupdown-wait-online
systemctl list-unit-files --state=enabled --no-pager > /root/enabled-before.txt
ls -l /etc/apache2/ports.conf /etc/apache2/sites-enabled/ /etc/nginx/mime.types \
      /etc/nginx/sites-enabled/ /etc/nginx/snippets/ /etc/systemd/system/*.d/ \
  > /root/conf-symlinks-before.txt
sudo -u off git -C /srv/opff log -1 --format='%H %s' > /root/git-before.txt   # as off: root gets "dubious ownership"
```

**Do not try to bring bullseye up to date first.** Since the end of bullseye
support (2026-08-31), `apt update` still answers but every package from
`security.debian.org bullseye-security` returns **404**, so `apt full-upgrade`
aborts without installing anything (harmless, but useless). Everything is
replaced by the bookworm hop anyway. If it is really wanted, point the security
line at `http://archive.debian.org/debian-security` first.

**Fix the network config now** (no restart needed, it is only read at boot).
The rootfs comes from off2 and `/etc/network/interfaces` has a stale `eth10`
stanza (same address as `eth0`), while the container only has `net0: name=eth0`.
At boot `ifup` fails on the missing `eth10`, `networking.service` fails (it was
already in the failed list on bullseye), and on trixie `ifupdown-wait-online`
then waits for it, holding `network-online.target`, so **nginx, munin-node and
exim4 do not start**. Same story for `systemd-networkd-wait-online`: networkd is
enabled but has no `.network` file, so it times out after 2 min.

```bash
grep -E '^(auto|iface)' /etc/network/interfaces   # compare with the netN: lines of /etc/pve/lxc/<CT>.conf
cp /etc/network/interfaces /root/interfaces.before-eth10-fix
# remove the eth10 stanza (adapt the address to the container)
perl -0pi -e 's/\nauto eth10\niface eth10 inet static\n\taddress 10\.13\.1\.115\/16\n\tgateway 10\.13\.0\.1\n//' /etc/network/interfaces
cat /etc/network/interfaces                       # lo + eth0 only
systemctl reset-failed networking; systemctl start networking; systemctl is-active networking
# (start, not restart: restart would take eth0 down)

ls /etc/systemd/network/ /run/systemd/network/    # no .network file → networkd manages nothing
systemctl disable systemd-networkd-wait-online.service
```

**Fix unattended-upgrades now** (it is also broken on bullseye). The
ansible-generated `/etc/apt/apt.conf.d/50unattended-upgrades` contains
`"origin=Debian,codename=bullseye,label=Debian-Security"`, but since bullseye
the security archive's codename is `<release>-security`: this pattern matches
nothing, so the container has probably **never received automatic security
updates**. Use the macro so it also survives the upgrade:

```bash
sed -i 's/"origin=Debian,codename=bullseye,label=Debian-Security";/"origin=Debian,codename=${distro_codename}-security,label=Debian-Security";/' \
  /etc/apt/apt.conf.d/50unattended-upgrades
unattended-upgrade --dry-run -d 2>&1 | grep -i 'allowed origins'   # …codename=bullseye-security…
```

(The same pattern comes from `ansible/roles/base/defaults/main.yml`
`base__unattended_origins_patterns`, see [Follow-ups](#follow-ups).)

**Speed-ups** (opff did not have them, its bookworm hop took one hour):

* purge the desktop packages the container carries for no reason (evince, yelp,
  webkit2gtk, mesa, gstreamer, ghostscript, ansible, aptitude…): hundreds of MB
  unpacked twice. Check first with `apt-cache rdepends --installed <pkg>` that
  nothing Product Opener needs depends on them, and read the `apt purge` plan.
* during the window, disable sync writes on the rootfs (on scaleway-01, see
  step 1): dpkg fsyncs every file, and the rootfs is on spinning disks. The
  snapshot is the safety net, so losing the last seconds in a crash only means
  a rollback.

Silence the monitoring alerts for the container for the duration of the window.

**Run the whole window inside `tmux` on scaleway-01** (`tmux new -s trixie`, then
`pct enter 115`): a dropped SSH session in the middle of dpkg is the one thing
that turns this into a recovery. Never interrupt (`^C`) apt while dpkg runs.

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

# check it really is the untouched system: 11.x, sources.list + mongodb list, no debian.sources
S=/zfs-hdd/pve/subvol-115-disk-0/.zfs/snapshot/$SNAP
cat $S/etc/debian_version; ls $S/etc/apt/ $S/etc/apt/sources.list.d/

# faster dpkg for the window (restored in step 5)
zfs set sync=disabled zfs-hdd/pve/subvol-115-disk-0
```

During the window, put up the maintenance page on `scaleway-proxy` if we have
one, otherwise the proxy will just answer 502.

### 2. bullseye → bookworm (transit only, ~1 hour on opff)

```bash
mkdir -p /root/apt-old && mv /etc/apt/sources.list /etc/apt/sources.list.d/*.list /root/apt-old/
# (this also drops the mongodb-org-4.4 repo: no bookworm/trixie build, and we stay on 4.4 server side)
ls /root/apt-old/     # sources.list + mongodb-org-4.4.list
# if this block is run a second time, mv says "cannot stat": harmless, the files are already there

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
apt $APT_OPTS upgrade --without-new-pkgs -y     # a long "kept back" list is expected
apt $APT_OPTS full-upgrade -y
```

`--force-confold` (and `UCF_FORCE_CONFFOLD` for the files managed by `ucf`) keeps
our versions of every modified config file (apache,
nginx, fail2ban, sudoers…) instead of prompting; the `*.dpkg-dist` files it leaves
are reviewed at step 5. No reboot, no perl rebuild, no test here: the site stays
down and we go straight on.

Before step 3, check the hop finished cleanly (**not** from a second terminal
while apt runs: `dpkg --audit` then lists the packages dpkg is busy with, and
must not be acted upon):

```bash
cat /etc/debian_version                       # 12.x
dpkg --audit                                  # must print nothing, else dpkg --configure -a
apt list --upgradable 2>/dev/null | wc -l     # 1
test -x /usr/sbin/policy-rc.d && echo "policy-rc.d still there"
```

### 3. bookworm → trixie

```bash
# in case this is a new shell
export DEBIAN_FRONTEND=noninteractive UCF_FORCE_CONFFOLD=1
APT_OPTS='-o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef'

sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/debian.sources
apt update
apt $APT_OPTS upgrade --without-new-pkgs -y
apt $APT_OPTS full-upgrade -y     # scroll the plan: apache2, nginx, libapache2-mod-perl2, perl must not be removed
apt autoremove --purge          # read the list before confirming
apt purge mongodb-database-tools   # leftover from the 4.4 repo, dumps are done on the MongoDB host
dpkg --audit                      # must print nothing
```

Expect many removals/renames from the 64-bit time transition (`libssl3t64`,
`libgeoip1t64`, …).

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
# release (v2.113.0 on opff) predates the pinning and fetches cpm from its main branch,
# so the values are read from origin/main, not from the checked-out Dockerfile
# (the fetch only updates origin/main, the checked-out code does not change)
sudo -u off git fetch origin main
CPM_COMMIT=$(sudo -u off git show origin/main:Dockerfile | sed -n 's/^ARG CPM_COMMIT=//p')
CPM_SHA256=$(sudo -u off git show origin/main:Dockerfile | sed -n 's/^ARG CPM_SHA256=//p')
[ -n "$CPM_COMMIT" ] && [ -n "$CPM_SHA256" ] || echo "cpm pin not found, stop here"
curl -fsSL "https://raw.githubusercontent.com/skaji/cpm/${CPM_COMMIT}/cpm" -o /usr/local/bin/cpm
echo "${CPM_SHA256}  /usr/local/bin/cpm" | sha256sum -c && chmod +x /usr/local/bin/cpm

# the root shell of `pct enter` has PATH=/sbin:/bin:/usr/sbin:/usr/bin, without
# /usr/local/bin ("cpm: command not found"): add it, and use the full path
export PATH=/usr/local/bin:$PATH

# global install into /usr/local/{share,lib}/perl/5.40.x, like before
/usr/local/bin/cpm install --show-build-log-on-failure -w $(nproc) -g Apache::Bootstrap
/usr/local/bin/cpm install --show-build-log-on-failure -w $(nproc) -g 2>&1 | tee /root/cpm-trixie.log
grep -E '^FAIL' /root/cpm-trixie.log      # must be empty, or understood

# smoke test the modules that matter
# (Apache2::* modules and the cgi scripts only load inside mod_perl, they are
# tested by apache starting in step 5, not here)
for m in MongoDB Imager Imager::zxing Image::Magick Minion Mojolicious OIDC::Lite GeoIP2 \
         GS1::SyntaxEngine::FFI; do
  sudo -u off perl -M$m -e "print qq{$m ok\n}" 2>&1 | tail -1
done
```

**Convert the timezone database of `DateTime::Lite`**, like the `Dockerfile`
does (required since Product Opener v2.112.0). Its `tz.sqlite3` ships in WAL
journal mode, which needs to create `-wal`/`-shm` files next to it even to
read; cpm installed it as root under `/usr/local`, and apache runs as `off`, so
every timezone lookup fails with, in the apache error log:
`Cannot prepare resolve_alias: attempt to write a readonly database`.

```bash
TZDB=$(find /usr/local -path '*DateTime/Lite/tz.sqlite3'); echo "$TZDB"
perl -MDBI -e 'for my $f (@ARGV) { my $d = DBI->connect("dbi:SQLite:dbname=$f","","",{RaiseError=>1}); print "$f: ", $d->selectrow_array("PRAGMA journal_mode=DELETE"), "\n"; $d->disconnect }' $TZDB
# prints "delete"; no tz.sqlite3-wal / -shm must remain next to it
```

This must be redone whenever cpm reinstalls `DateTime::Lite` (e.g. a deploy
that bumps its version in the `cpanfile`), see [Follow-ups](#follow-ups).

### 5. Restore config, start, check

```bash
# configs that dpkg may have replaced: compare with step 0
ls -l /etc/apache2/ports.conf /etc/apache2/sites-enabled/ /etc/nginx/mime.types \
      /etc/nginx/sites-enabled/ /etc/nginx/snippets/ /etc/systemd/system/*.d/ \
  | diff /root/conf-symlinks-before.txt -
```

Expected difference: `/etc/systemd/system/netfilter-persistent.service.d/` is now
empty. Nothing is lost: `ipset-persistent`/`iptables-persistent` now ship
`ipset.conf`/`iptables.conf` in `/usr/lib/systemd/system/netfilter-persistent.service.d/`
(`systemctl cat netfilter-persistent` shows them).

Review the files dpkg left next to ours, then delete them:

```bash
for f in $(find /etc -name '*.dpkg-dist' -o -name '*.ucf-dist'); do echo "=== $f"; diff -u "${f%.*}" "$f"; done | less
for f in $(find /etc -name '*.dpkg-new'); do echo "=== $f"; ls -l "${f%.dpkg-new}"; diff -u "${f%.dpkg-new}" "$f"; done | less
```

What opff had, and what was decided:

| File | Decision |
| --- | --- |
| `apache2/ports.conf.dpkg-new`, `nginx/mime.types.dpkg-new` | ours are symlinks into `/srv/opff/conf`, keep them (check they still are symlinks). New mime types, if useful, go to the git repo |
| `apache2/mods-available/mpm_prefork.conf.dpkg-new` | keep ours (our tuning, uses the `APACHE_MPM_*` variables) |
| `logrotate.d/apache2.dpkg-new`, `logrotate.d/nginx.dpkg-new` | keep ours if the diff only shows our changes |
| `sudoers.dpkg-dist` | keep ours (`NOPASSWD` for group `sudo`), `visudo -c` |
| `ssh/sshd_config.ucf-dist` | keep ours (ansible-managed; the default turns `X11Forwarding` back on), **`sshd -t` must print nothing** |
| `GeoIP.conf.dpkg-dist` | keep ours (MaxMind account and licence key) |
| `apt/apt.conf.d/50unattended-upgrades.ucf-dist` | keep ours, with the origin fix of step 0 |
| `crontab.dpkg-dist`, `perl/XML/SAX/ParserDetails.ini.ucf-dist`, `systemd/timesyncd.conf.dpkg-dist` | keep ours (only times, order or comments differ) |
| `cron.d/e2scrub_all.dpkg-dist` | take the new one (`/usr/libexec/e2fsprogs` path) |

The `.dpkg-new` files did **not** mean unconfigured packages: `dpkg --audit` was
empty and `dpkg -l apache2 nginx…` all `ii`.

```bash
mv /etc/cron.d/e2scrub_all.dpkg-dist /etc/cron.d/e2scrub_all
find /etc \( -name '*.dpkg-dist' -o -name '*.ucf-dist' -o -name '*.dpkg-new' \) -delete

sshd -t
# apache's config needs APACHE2_PORT and APACHE_MPM_* from the env file that the
# systemd drop-in loads: without it configtest fails with "Port must be specified"
systemctl cat apache2 | grep -iE 'environment|^# /'
( set -a; . /srv/opff/env/env.opff; set +a; apache2ctl configtest )
nginx -t
systemctl daemon-reload

# allow services to start again
rm /usr/sbin/policy-rc.d
```

```bash
# on scaleway-01: back to normal sync writes
zfs inherit sync zfs-hdd/pve/subvol-115-disk-0
```

If `nginx -t` complains about an unknown directive: trixie folded
`nginx-full`/`nginx-light` into a single `nginx` package, some modules may now be
dynamic, check `/etc/nginx/modules-enabled/`.

Then reboot the container (from scaleway-01: `pct reboot 115`) so that everything
starts like it will in normal life, and check:

```bash
systemctl list-jobs --no-pager            # "No jobs running." — if nginx waits behind
                                          # *-wait-online, the step 0 network fix is missing
cat /etc/debian_version                   # 13.x
perl -v | head -2                         # 5.40
systemctl is-active networking nginx apache2 minion@opff redis_listener@opff cloud_vision_ocr@opff
systemctl list-units --failed --no-pager | diff /root/failed-before.txt -
systemctl list-unit-files --state=enabled --no-pager | diff /root/enabled-before.txt -
#   (apt-daily*/unattended-upgrades show up here until re-enabled below)
sudo -u off git -C /srv/opff log -1 --format='%H %s' | diff /root/git-before.txt -
sudo -u off git -C /srv/opff status --short           # only the known untracked entries
curl -sS -o /dev/null -w '%{http_code} %{time_total}s\n' -H 'Host: world.openpetfoodfacts.org' http://127.0.0.1/
curl -sS -o /dev/null -w '%{http_code} %{time_total}s\n' -H 'Host: world.openpetfoodfacts.org' http://127.0.0.1/api/v2/product/3017620422002
journalctl -u apache2 -u minion@opff -p warning -b --no-pager | tail -50
tail -50 /srv/opff/logs/*.log /var/log/apache2/error.log
```

apache takes ~25 s to start on opff (Product Opener's startup at 100% CPU,
~1.1 GB resident): don't conclude too fast that it is stuck.

From outside, on <https://world.openpetfoodfacts.org>: front page, search, a
product page, product images (ImageMagick 7), login, **one product edit** and **one
image upload** (minion processes it), the API. Then re-enable the timers
and the monitoring alerts:

```bash
systemctl enable --now unattended-upgrades apt-daily.timer apt-daily-upgrade.timer
apt-cache policy | grep -A1 'debian-security' | grep release   # n=trixie-security, l=Debian-Security
```

### Rollback (any time, seconds)

```bash
# on scaleway-01
pct stop 115
zfs rollback -r zfs-hdd/pve/subvol-115-disk-0@pre-trixie_<date>
zfs inherit sync zfs-hdd/pve/subvol-115-disk-0
pct start 115
# in the container: the snapshot was taken after step 1
rm -f /usr/sbin/policy-rc.d
systemctl enable --now unattended-upgrades apt-daily.timer apt-daily-upgrade.timer
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

## Follow-ups

* **unattended-upgrades on all ansible-managed hosts**:
  `ansible/roles/base/defaults/main.yml` sets
  `origin=Debian,codename={{ distribution_release }},label=Debian-Security`,
  which matches no origin since bullseye (the security codename is
  `<release>-security`). Hosts on bullseye or later probably get no automatic
  security updates. To be confirmed on a host and fixed in the role.
* the `tz.sqlite3` conversion of step 4 is lost each time cpm reinstalls
  `DateTime::Lite` on a production container: add it to the production deploy
  procedure (or make Product Opener open the file read-only / in DELETE mode).
* the stale `eth10` stanza and the networkd wait unit are probably on every
  container cloned from the off2 rootfs (opf, obf, off-pro, off): fixed by
  step 0 of this procedure.

## Log

### opff (CT 115), 2026-10-15

* `apt full-upgrade` on bullseye: every `bullseye-security` package answered
  404 (end of support), nothing installed. Skipped, see step 0.
* snapshot `zfs-hdd/pve/subvol-115-disk-0@pre-trixie_2026-10-15_1209`, checked:
  `11.10`, original `sources.list` and `mongodb-org-4.4.list`.
* the step 2 block was run twice (a first attempt was interrupted with `^C`):
  the second `mv` failed with "cannot stat", harmless, `/root/apt-old` held the
  original files.
* bullseye → bookworm: about **one hour** (sync writes still enabled, no package purge).
* bookworm → trixie: ran without problems; a `dpkg --audit` from a second
  terminal while it ran showed half-configured packages, which is only dpkg
  at work.
* deployed code: **v2.113.0** (`423016adfb`, deployed after the 2026-10-05
  inventory, which said 2.109.0), unchanged by the upgrade.
* cpm downloaded and verified, but `cpm: command not found`: the `pct enter`
  root shell has `PATH=/sbin:/bin:/usr/sbin:/usr/bin` → full path.
* after start, the apache error log showed `Cannot prepare resolve_alias:
  attempt to write a readonly database`: the `DateTime::Lite` `tz.sqlite3` in
  WAL mode, not writable by `off`. Converted to `journal_mode=DELETE` (now in
  step 4), apache restarted.
* config review: see the table in step 5. `50unattended-upgrades` was fixed
  (it still said `codename=bullseye`, and never matched the security archive).
* `apache2ctl configtest` by hand: "Port must be specified" — the env file was
  not loaded, not a regression.
* first reboot (16:24 CEST): apache up in ~25 s. **nginx stayed "inactive (dead)"
  with a waiting job**: `networking` failed on the stale `eth10` stanza,
  `ifupdown-wait-online` waited for it, `systemd-networkd-wait-online` timed out
  after 2 min. `systemctl cancel` of the wait job started nginx; fixed by
  removing `eth10` from `/etc/network/interfaces` and disabling
  `systemd-networkd-wait-online` (now in step 0).
* checked: login, product edit, image selection/crop.
* to do: reboot again to check a clean boot (no waiting job), functional checks
  from outside, re-enable apt timers and monitoring, restore `sync` if it was
  disabled.
