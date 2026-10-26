# 2026-10-15 Product Opener containers: in-place Debian → trixie upgrade

Simpler alternative to
[2026-10-05-opff-debian-bullseye-to-trixie-upgrade.md](./2026-10-05-opff-debian-bullseye-to-trixie-upgrade.md):
no blue/green container, no cloned data volumes, no dataset swap.
The container is upgraded **in place**, during a maintenance window,
with a **ZFS snapshot of the rootfs** as the rollback.

opff (CT 115) was done first, on 2026-10-15, then off-pro (CT 112) on
2026-10-20 and opf (CT 114) on 2026-10-26: see the [Log](#log). The procedure
below includes everything learned on them.

## Why this is reasonably safe

* **The application stack is already validated on trixie**: staging and dev run
  Product Opener from the `Dockerfile` (`FROM debian:trixie-slim`), i.e. perl 5.40,
  ImageMagick 7, tesseract 5, apache 2.4 + mod_perl, and the same `cpanfile`
  (pinned `MongoDB 2.2.x` talking to the MongoDB 4.4 server, `Type::Tiny::XS 0.025`, …).
  What remains specific to production is the host config, not the code.
* **The data is not in the rootfs**: products, images, users, orgs, html_data, cache
  are separate datasets (or NFS mounts) mounted into the container (`mpN`).
  The upgrade only touches the rootfs, so rolling back the rootfs never loses data.
* **Rollback is one command** (`zfs rollback`) and takes seconds.
* **scaleway-01 runs proxmox-ve 9.2**, which knows Debian 13 (the trap that bit
  matomo on ovh2 does not apply).

## Containers and order

All on `scaleway-01`, all clones of the same rootfs, so each one teaches us
something about the next ones:

| Order | CT | Hostname | Site |
| --- | --- | --- | --- |
| 1 (canary) | 115 | `opff` | openpetfoodfacts.org — **done 2026-10-15** |
| 2 | 112 | `off-pro` | pro.openfoodfacts.org — **done 2026-10-20** |
| 3 | 114 | `opf` | openproductsfacts.org — **done 2026-10-26** |
| 4 | 113 | `obf` | openbeautyfacts.org |
| 5 | 111 | `off` | openfoodfacts.org (own window, after a few quiet days) |

Write down in the [Log](#log) every surprise met (prompts, clobbered configs,
failed modules), with rough times.

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

The cost: the site is down for the whole window, instead of ~5 min.

| | opff (no speed-ups) | off-pro (speed-ups of step 0) | opf (speed-ups) |
| --- | --- | --- | --- |
| bullseye → bookworm | ~1 h | **10 min** | **5 min** |
| bookworm → trixie | (not measured) | **16 min** | **~11 min** |
| perl modules, config review, reboot, checks | | 19 min | ~8 min |
| **downtime** | 2–3 h | **~55 min** | **~26 min** |

The speed-ups are purging the unused desktop packages before the window and
disabling ZFS sync writes during it (step 0 and step 1). Plan about one hour of
downtime with them (opf, the third one, took less than half an hour).

Keeping the site up during `full-upgrade` is **not** an option: perl, libc,
libssl and ImageMagick are replaced under the running processes, mod_perl can no
longer load the 5.32 CPAN modules, and half-done writes would land on the data
datasets, which a rootfs rollback does not cover. A site that must stay up needs
the blue/green plan of 2026-10-05.

## Procedure

Set these in every shell, on scaleway-01 and in the container (example: off-pro):

```bash
CT=112; I=off-pro; DS=zfs-hdd/pve/subvol-$CT-disk-0; H=world.pro.openfoodfacts.org
```

(opff: `CT=115; I=opff; H=world.openpetfoodfacts.org`.)

Commands starting with `zfs` or `pct` run **on scaleway-01**, everything else
**in the container** (`pct enter $CT`). Check the prompt before pasting.

### 0. Before the window (site still up, the day before is fine)

**On scaleway-01:**

```bash
pct config $CT                       # note the netN: lines and the mpN: mount points
zfs get refquota,used,available $DS  # ~6G free needed; refquota may be "none" (no quota)
```

If there is a quota and less than ~6G is available, raise it first
(`pct resize $CT rootfs 40G`).

**In the container — baselines:**

```bash
cat /etc/debian_version
sudo -u off git -C /srv/$I describe --tags         # deployed release; >= v2.112.0 means DateTime::Lite (step 4)
dpkg-query -W -f='${binary:Package}\t${Version}\n' | sort > /root/dpkg-before.tsv
apt-mark showmanual | sort > /root/apt-manual-before.txt
systemctl list-units --failed --no-pager > /root/failed-before.txt   # opff: gen_feeds_daily, networking, ifupdown-wait-online
systemctl list-unit-files --state=enabled --no-pager > /root/enabled-before.txt
ls -l /etc/apache2/ports.conf /etc/apache2/sites-enabled/ /etc/nginx/mime.types \
      /etc/nginx/sites-enabled/ /etc/nginx/snippets/ /etc/systemd/system/*.d/ \
  > /root/conf-symlinks-before.txt
sudo -u off git -C /srv/$I log -1 --format='%H %s' > /root/git-before.txt   # as off: root gets "dubious ownership"

# the units of this instance: what step 1 stops and step 5 checks
systemctl list-units --all --plain --no-legend "*@$I.*" | tee /root/units-$I.txt
crontab -u off -l 2>/dev/null; ls /etc/cron.d/

# third-party apt repositories: see step 2
ls /etc/apt/sources.list.d/; cat /etc/apt/sources.list.d/*.list
```

off-pro had these units: `minion@`, `redis_listener@`, `cloud_vision_ocr@`
(running), `producers_import@` and `gen_feeds_daily@` (services + timers).

**Do not try to bring bullseye up to date first.** Since the end of bullseye
support (2026-08-31), `apt update` still answers but every package from
`security.debian.org bullseye-security` returns **404**, so `apt full-upgrade`
aborts without installing anything (harmless, but useless). Everything is
replaced by the bookworm hop anyway. If it is really wanted, point the security
line at `http://archive.debian.org/debian-security` first.

**Fix the network config.** At boot, anything ordered after
`network-online.target` (nginx, munin-node, exim4) waits for the
`*-wait-online` units. On trixie this blocked nginx on opff:

* opff's `/etc/network/interfaces` had a stale `eth10` stanza (same address as
  `eth0`, left from off2) while the container only has `net0: name=eth0`:
  `networking.service` failed (already on bullseye) and `ifupdown-wait-online`
  waited for it. off-pro did **not** have it.
* `systemd-networkd` is enabled but has no `.network` file, so
  `systemd-networkd-wait-online` times out after 2 min (both opff and off-pro).

```bash
grep -E '^(auto|iface)' /etc/network/interfaces   # only lo + the netN of `pct config`
systemctl is-active networking; grep -E 'networking|wait-online' /root/failed-before.txt

# only if there is a stale stanza (adapt the address):
cp /etc/network/interfaces /root/interfaces.before-fix
perl -0pi -e 's/\nauto eth10\niface eth10 inet static\n\taddress 10\.13\.1\.115\/16\n\tgateway 10\.13\.0\.1\n//' /etc/network/interfaces
systemctl reset-failed networking; systemctl start networking; systemctl is-active networking
# (start, not restart: restart would take eth0 down)

ls /etc/systemd/network/ /run/systemd/network/ 2>/dev/null   # no .network file → networkd manages nothing
systemctl disable systemd-networkd-wait-online.service
```

**Fix unattended-upgrades** (it is also broken on bullseye). The
ansible-generated `/etc/apt/apt.conf.d/50unattended-upgrades` contains
`"origin=Debian,codename=bullseye,label=Debian-Security"`, but since bullseye
the security archive's codename is `<release>-security`: this pattern matches
nothing, so the container has probably **never received automatic security
updates**. Use the macro so it also survives the upgrade:

```bash
sed -i 's/"origin=Debian,codename=bullseye,label=Debian-Security";/"origin=Debian,codename=${distro_codename}-security,label=Debian-Security";/' \
  /etc/apt/apt.conf.d/50unattended-upgrades
grep -A3 Origins-Pattern /etc/apt/apt.conf.d/50unattended-upgrades
```

(The same pattern comes from `ansible/roles/base/defaults/main.yml`
`base__unattended_origins_patterns`, see [Follow-ups](#follow-ups).)

**Purge the unused desktop packages** (speed-up, done on off-pro: ~850 MB less
to unpack twice). Site still up, so each step is simulated and checked first.
Keep **`gnumeric`**: its `ssconvert` converts producers' spreadsheets.

```bash
apt-get -s purge evince yelp aptitude ansible 2>&1 | grep '^Purg'
# off-pro: only these + gnumeric-doc. gnumeric, imagemagick*, graphviz, tesseract*,
# libapache2-mod-perl2 must NOT be in the list
apt-get purge -y evince yelp aptitude ansible gnumeric-doc

# the real gain is the dependencies left behind (webkit, gstreamer, mesa…)
apt-get -s autoremove --purge 2>&1 | grep '^Purg' | tee /root/autoremove-sim.txt | wc -l
grep -iE 'gnumeric|goffice|gsf|magick|graphviz|tesseract|perl|apache|nginx|mod-perl' /root/autoremove-sim.txt   # must print nothing

# apt does not know which system libraries the CPAN XS modules use: check that
# none of them is in the list (both counts must be well above 0 for this to mean anything)
LIBS=$(awk '{print $2}' /root/autoremove-sim.txt | sed 's/:.*//' | xargs -r dpkg -L 2>/dev/null | grep -E '\.so(\.[0-9]+)*$' | xargs -r -n1 basename | sort -u)
echo "$LIBS" | wc -l
find /usr/local/lib/x86_64-linux-gnu/perl /usr/local/lib/x86_64-linux-gnu/perl5 /usr/local/share/perl -name '*.so' 2>/dev/null | wc -l
find /usr/local/lib/x86_64-linux-gnu/perl /usr/local/lib/x86_64-linux-gnu/perl5 /usr/local/share/perl -name '*.so' 2>/dev/null \
  | xargs -r ldd 2>/dev/null | awk '{print $1}' | sort -u | grep -Fxf <(echo "$LIBS")    # must print nothing

apt-get autoremove --purge -y

# still working?
printf 'code,product_name\n3017620422003,test\n' > /tmp/t.csv
sudo -u off ssconvert /tmp/t.csv /tmp/t.xlsx && sudo -u off ssconvert /tmp/t.xlsx /tmp/t2.csv && cat /tmp/t2.csv
curl -sS -o /dev/null -w '%{http_code}\n' -H "Host: $H" http://127.0.0.1/
```

On opf, the autoremove list was longer (261 packages): it also had ~25
`python3-*` modules pulled in by `ansible` (`yaml`, `jinja2`, `requests-*`…).
As for the CPAN check, apt does not know which local scripts import them:

```bash
grep -rlE '^\s*(import|from)\s+(yaml|jinja2|requests|packaging|pyparsing|simplejson|dns|netaddr|xmltodict|markupsafe)\b' \
  /srv/$I/scripts /srv/$I/lib /srv/$I/conf /usr/local/bin 2>/dev/null | head
crontab -u off -l 2>/dev/null; ls /etc/cron.d/
```

On opf it only matched `scripts/packager-codes/*.py`: developer tools run by
hand, with their own `requirements.txt` (pip virtualenv), not run by any timer
or cron on the container. Not a reason to keep the packages.

A `500` from that last `curl` is not necessarily the purge: on opf it most likely came from
nginx running out of connections under crawler load
(`768 worker_connections are not enough` in `/var/log/nginx/error.log`), a
second `curl` gave `200` (see [Follow-ups](#follow-ups)).

**Silence the monitoring alerts** for the window: in
[Alertmanager](https://alertmanager.openfoodfacts.org/), *New Silence* matching
the site's blackbox probe (e.g. the `world.openproductsfacts.org` target, see
`configs/prometheus/config.yml` in openfoodfacts-monitoring), for ~2 hours;
*Expire* it at the end of step 5. For off-pro, announce the window to the
producers. Run the window during the day: `gen_feeds_daily@` runs at night
(02:15 on off-pro, 05:00 on opf).

**Never interrupt (`^C`) apt while dpkg runs.** The long apt runs of steps 2
and 3 are launched with `nohup` (see step 2), so a dropped SSH connection does
not kill them. No need for tmux: on off-pro, leaving tmux with `exit` made the
shell run the commands still queued from a pasted block (an extra snapshot was
taken and `sync=disabled` set again after the reboot).

### 1. Stop the site and snapshot the rootfs

Check that no import or feed generation is running or about to start:

```bash
systemctl list-timers --all --no-pager "*@$I.timer"
systemctl is-active $(awk '/\.service/ {print $1}' /root/units-$I.txt)   # the oneshot ones must be "inactive"
```

```bash
# in the container
systemctl stop apache2 nginx cron $(awk '{print $1}' /root/units-$I.txt)

# the instance timers must not fire at the step 5 reboot, before the manual tests.
# Do NOT `systemctl disable` them: they were added with `systemctl link`, and
# disable also deletes the link to /srv/$I/conf/systemd/ (happened on off-pro,
# restored from etckeeper). Remove only their boot links:
ls -l /etc/systemd/system/*.wants/*@$I.timer | tee /root/timer-wants-$I.txt
rm /etc/systemd/system/*.wants/*@$I.timer

# disabled (not only stopped), otherwise they start again at the step 5 reboot,
# before validation, with Automatic-Reboot "true"
systemctl disable --now unattended-upgrades apt-daily.timer apt-daily-upgrade.timer

# package upgrades restart enabled services even if they are stopped: apache would
# then come back with mod_perl and no rebuilt CPAN modules, and a failing restart
# can make the postinst fail and stop the full-upgrade. Forbid any service start
# until step 5.
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d
```

On scaleway-01, paste this block **on its own**:

```bash
# the rollback point (non-autosnap name, so sanoid keeps it)
SNAP=pre-trixie_$(date --utc +%Y-%m-%d_%H%M); zfs snapshot $DS@$SNAP; echo $SNAP

# check it really is the untouched system: 11.x, the old .list files, no debian.sources
S=/$DS/.zfs/snapshot/$SNAP; cat $S/etc/debian_version; ls $S/etc/apt/sources.list.d/

# faster dpkg for the window (restored in step 5)
zfs set sync=disabled $DS
```

Write down the snapshot name. During the window, put up the maintenance page on
`scaleway-proxy` if we have one, otherwise the proxy will just answer 502.

### 2. bullseye → bookworm (transit only, 10 min on off-pro)

Move away the Debian sources and the repositories that have no bookworm/trixie
build (`mongodb-org-4.4`: no build, and we stay on 4.4 server side). **Keep**
third-party repositories whose suite is not a Debian codename: off-pro has
`google-cloud-sdk.list` (`cloud-sdk main`), needed by the nightly producer
import (`scripts/imports/carrefour/run_carrefour_import_images.sh` uses
`gcloud storage cp`).

```bash
mkdir -p /root/apt-old && mv /etc/apt/sources.list /etc/apt/sources.list.d/mongodb-org-4.4.list /root/apt-old/
ls /root/apt-old/ /etc/apt/sources.list.d/
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
```

The upgrade itself runs in the background with `nohup`, so it survives a
dropped SSH connection; everything is non-interactive:

```bash
cat > /root/apt-hop.sh <<'EOF'
export DEBIAN_FRONTEND=noninteractive UCF_FORCE_CONFFOLD=1
O='-o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef'
apt-get update && apt-get $O upgrade -y && apt-get $O dist-upgrade -y
echo "=== HOP FINISHED, exit code $?"
EOF

setsid nohup bash /root/apt-hop.sh > /root/apt-bookworm.log 2>&1 &
tail -f /root/apt-bookworm.log     # ^C only stops tail; after a disconnect: pct enter, tail -f again
```

`apt-get upgrade` first upgrades what needs no new package (a long "kept back"
list is expected), `dist-upgrade` does the rest. `--force-confold` (and
`UCF_FORCE_CONFFOLD` for the files managed by `ucf`) keeps our versions of
every modified config file instead of prompting; the `*.dpkg-dist` files it
leaves are reviewed at step 5. No reboot, no perl rebuild, no test here: the
site stays down and we go straight on.

When the log shows `=== HOP FINISHED, exit code 0`, check the hop finished
cleanly (**not** while apt runs: `dpkg --audit` then lists the packages dpkg is
busy with, and must not be acted upon):

```bash
cat /etc/debian_version                       # 12.x
dpkg --audit                                  # must print nothing, else dpkg --configure -a
apt list --upgradable 2>/dev/null | wc -l     # 1
test -x /usr/sbin/policy-rc.d && echo "policy-rc.d still there"
```

### 3. bookworm → trixie (16 min on off-pro)

```bash
sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/debian.sources
setsid nohup bash /root/apt-hop.sh > /root/apt-trixie.log 2>&1 &
tail -f /root/apt-trixie.log
```

Then check that the important packages survived (a `grep` on the "REMOVED"
section of the log is unreliable, it also catches the "NEW" list):

```bash
dpkg -l apache2 nginx libapache2-mod-perl2 perl imagemagick libimage-magick-perl gnumeric google-cloud-cli 2>&1 \
  | grep -vE '^(Desired|\||\+)' | awk '{print $1, $2, $3}'     # all "ii" (google-cloud-cli: off-pro only)
```

Expected removals: `imagemagick-6-common` (IM6 → IM7), `libapr1`/`libaprutil1`/
`libapreq2-3` (renamed `…t64`), `libbson-xs-perl` (dropped by Debian; the
MongoDB driver falls back to pure-perl BSON, as in the Docker images).

```bash
apt autoremove --purge          # without -y: read the list (gnumeric, google-cloud-cli, imagemagick* must not be in it)
cat /etc/debian_version; dpkg --audit   # 13.x, nothing

# openssh-server disables ssh.service when it is upgraded (it "synchronizes"
# systemd with the old SysV links): on opf both the bookworm and the trixie
# hops did it. Turn it back on if /root/enabled-before.txt had it:
grep -E '^ssh' /root/enabled-before.txt
systemctl enable ssh; systemctl is-enabled ssh ssh.socket
```

**Do not purge `mongodb-database-tools`**: `mongoexport` and `mongodump` are
run every night by `scripts/mongodb_dump.sh` (called by
`gen_feeds_daily@$I`) to make the public JSONL and MongoDB dumps. The
`mongodb-org-4.4` repo has no bookworm/trixie build, so replace the package
with **the same version, 100.10.0**, from MongoDB's standalone Debian 12
package (works on trixie). The database tools are versioned separately from
the server (100.x), and 100.10.0 is what talked to the 4.4 server before the
upgrade, so nothing changes on the MongoDB side:

```bash
cd /root
wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-debian12-x86_64-100.10.0.deb
apt install ./mongodb-database-tools-debian12-x86_64-100.10.0.deb
mongoexport --version | head -1; mongodump --version | head -1   # 100.10.0
```

(off-pro does not need them, `gen_feeds_daily.sh` skips the dumps on the pro
platform; install them anyway to keep the containers identical.)

On off-pro this `autoremove` also removed:

* **`libapache2-request-perl` and `libapache2-mod-apreq2`**, and with them
  `/etc/apache2/mods-enabled/apreq2.load`: Product Opener needs them
  (`Apache2::Request`). Step 4's `apt install` of the Dockerfile packages puts
  them back and re-enables the module — checked there.
* **the `libnginx-mod-*` modules** (geoip, image-filter, xslt, mail, stream): on
  trixie `nginx` no longer depends on them. Harmless if the config does not use
  their directives:

```bash
grep -rnE 'geoip|image_filter|xslt_|^\s*(mail|stream)\s*\{' /srv/$I/conf/nginx/ /etc/nginx/ 2>/dev/null | grep -v '#'
nginx -t     # if it fails on a geoip_* directive: apt install libnginx-mod-http-geoip
```

### 4. Rebuild the perl dependencies, the way staging does

The old CPAN modules live in `/usr/local/share/perl/5.32.1` and
`/usr/local/lib/x86_64-linux-gnu/perl/5.32.1`: perl 5.40 simply does not look
there anymore, so there is nothing to remove now (delete them at cleanup).

```bash
# apt packages: exactly the list the Dockerfile installs (modperl stage)
cd /srv/$I
PKGS=$(perl -ne 'last if /^FROM modperl AS builder/; $in=1 if /apt-get install/;
  if ($in) { print "$1\n" if /^\s+([a-z0-9][a-z0-9.+-]+)\s*\\?\s*$/; $in=0 if !/\\\s*$/ && !/^\s*#/ }' Dockerfile | sort -u)
echo $PKGS
apt install -y --no-install-recommends $PKGS

# apreq is back (see step 3)?
dpkg -l libapache2-request-perl libapache2-mod-apreq2 | grep '^ii' | awk '{print $1, $2, $3}'
ls -l /etc/apache2/mods-enabled/ | grep -i apreq     # else: apt install libapache2-mod-apreq2 && a2enmod apreq2

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

# off-pro: the producers' tools
which ssconvert && ssconvert --version | head -1
sudo -u off gcloud --version | head -1
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
# prints "delete" (also for the old 5.32.1 copy, harmless); no tz.sqlite3-wal / -shm must remain
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

Review the files dpkg left next to ours, then delete them. The review is saved
to a file, which is easier to read (or copy) than the terminal scrollback:

```bash
for f in $(find /etc -name '*.dpkg-dist' -o -name '*.ucf-dist' -o -name '*.dpkg-new'); do
  echo "=== $f"; ls -l "${f%.*}"; diff -u "${f%.*}" "$f"
done > /root/conf-review.txt 2>&1
grep '^===' /root/conf-review.txt                                  # the list
sed -n '/=== \/etc\/ssh\/sshd_config/,/^===/p' /root/conf-review.txt   # one file's diff
# whole file to a workstation: on scaleway-01, cp /$DS/root/conf-review.txt ~stephane/
```

The containers kept etckeeper: every apt run commits `/etc`, so
`cd /etc && git log --stat` shows what each step changed, and
`git checkout HEAD -- <path>` restores a file.

What opff and off-pro had (the same list, plus fail2ban on off-pro), and what
was decided:

| File | Decision |
| --- | --- |
| `apache2/ports.conf.dpkg-new`, `nginx/mime.types.dpkg-new` | ours are symlinks into `/srv/$I/conf`, keep them (check they still are symlinks). New mime types, if useful, go to the git repo |
| `apache2/mods-available/mpm_prefork.conf.dpkg-new` | keep ours (our tuning, uses the `APACHE_MPM_*` variables) |
| `logrotate.d/apache2.dpkg-new`, `logrotate.d/nginx.dpkg-new` | keep ours if the diff only shows our changes |
| `sudoers.dpkg-dist` | keep ours (`NOPASSWD` for group `sudo`), `visudo -c` |
| `ssh/sshd_config.ucf-dist` | keep ours (ansible-managed; the default turns `X11Forwarding` back on), **`sshd -t` must print nothing** |
| `GeoIP.conf.dpkg-dist` | keep ours (MaxMind account and licence key) |
| `apt/apt.conf.d/50unattended-upgrades.ucf-dist` | keep ours, with the origin fix of step 0 |
| `crontab.dpkg-dist`, `perl/XML/SAX/ParserDetails.ini.ucf-dist`, `systemd/timesyncd.conf.dpkg-dist` | keep ours (only times, order or comments differ) |
| `cron.d/e2scrub_all.dpkg-dist` | take the new one (`/usr/libexec/e2fsprogs` path) |
| `fail2ban/jail.d/defaults-debian.conf.dpkg-dist` | delete it: ours is absent on purpose, the ansible fail2ban role (`oefenweb.fail2ban`) removes it and defines the jails. Check `fail2ban-client -t` says OK |

The `.dpkg-new` files did **not** mean unconfigured packages: `dpkg --audit` was
empty and `dpkg -l apache2 nginx…` all `ii`.

```bash
mv /etc/cron.d/e2scrub_all.dpkg-dist /etc/cron.d/e2scrub_all
find /etc \( -name '*.dpkg-dist' -o -name '*.ucf-dist' -o -name '*.dpkg-new' \) -delete

sshd -t
visudo -c
fail2ban-client -t
# apache's config needs APACHE2_PORT and APACHE_MPM_* from the env file that the
# systemd drop-in loads (EnvironmentFile=/srv/%l/env/env.%l): without it
# configtest fails with "Port must be specified"
systemctl cat apache2 | grep -iE 'environment|^# /'
( set -a; . /srv/$I/env/env.$I; set +a; apache2ctl configtest )
nginx -t
systemctl daemon-reload

# allow services to start again
rm /usr/sbin/policy-rc.d
```

If `nginx -t` complains about an unknown directive: trixie folded
`nginx-full`/`nginx-light` into a single `nginx` package and the
`libnginx-mod-*` modules may have been autoremoved (step 3).

On scaleway-01, back to normal sync writes, then reboot so that everything
starts like it will in normal life:

```bash
zfs inherit sync $DS; zfs get sync $DS     # standard
pct reboot $CT
```

Then, in the container (`pct enter $CT` again):

```bash
systemctl list-jobs --no-pager            # "No jobs running." — if nginx waits behind
                                          # *-wait-online, the step 0 network fix is missing
cat /etc/debian_version                   # 13.x
perl -v | head -2                         # 5.40
systemctl is-active networking nginx apache2 ssh $(awk '/running/ {print $1}' /root/units-$I.txt)
ss -ltnp | grep ':22 '                    # sshd listening (see step 3)
systemctl list-units --failed --no-pager | diff /root/failed-before.txt -
systemctl list-unit-files --state=enabled --no-pager | diff /root/enabled-before.txt -
#   (apt-daily*/unattended-upgrades and the instance timers show up here until re-enabled below)
sudo -u off git -C /srv/$I log -1 --format='%H %s' | diff /root/git-before.txt -
sudo -u off git -C /srv/$I status --short           # only the known untracked entries
curl -sS -o /dev/null -w '%{http_code} %{time_total}s\n' -H "Host: $H" http://127.0.0.1/
journalctl -u apache2 -u minion@$I -p warning -b --no-pager | tail -50
grep -iE 'resolve_alias|readonly|Can.t locate|apreq' /var/log/apache2/error.log | tail
which mongoexport mongodump               # both present (step 3), or the night's dumps come out empty
```

apache takes ~25 s to start (Product Opener's startup at 100% CPU, ~1.1 GB
resident on opff): don't conclude too fast that it is stuck.

From outside: front page, search, a product page, product images
(ImageMagick 7), login, **one product edit** and **one image upload** (minion
processes it), an image crop, the API. On off-pro also: an organisation's
product list, **a small CSV/XLSX import** (follow `journalctl -u minion@off-pro -f`),
**an export to the public platform** (a file appears in
`/mnt/off-pro/cache/export_files`).

Then re-enable the instance timers (this recreates their boot links from their
`[Install]` section), the apt timers and the monitoring alerts:

```bash
cat /root/timer-wants-$I.txt
systemctl enable --now $(awk '/\.timer/ {print $1}' /root/units-$I.txt)
systemctl enable --now unattended-upgrades apt-daily.timer apt-daily-upgrade.timer
systemctl list-timers --no-pager | grep -E "$I|apt"
apt-cache policy | grep -A1 'debian-security' | grep release   # n=trixie-security, l=Debian-Security
```

On off-pro, check the next night's import (`journalctl -u producers_import@off-pro --since yesterday`),
including the Carrefour `gcloud storage cp` step.

On the public sites, check the next night's dumps: the files must be dated
from the night and **not 20 bytes** (an empty gzip, what `mongodb_dump.sh`
writes when `mongoexport` fails):

```bash
ls -la /srv/$I/html/data/*.jsonl.gz /srv/$I/html/data/*mongodbdump.gz
journalctl -u gen_feeds_daily@$I --since yesterday --no-pager | grep -E "errors during execution of ./mongodb_dump.sh|FAILED COMMANDS" -A3
```

### Rollback (any time, seconds)

```bash
# on scaleway-01
pct stop $CT
zfs rollback -r $DS@pre-trixie_<date>
zfs inherit sync $DS
pct start $CT
# in the container: the snapshot was taken after step 1
rm -f /usr/sbin/policy-rc.d
systemctl enable --now $(awk '/\.timer/ {print $1}' /root/units-$I.txt)
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
zfs destroy $DS@pre-trixie_<date>
```

## Known points to watch

* **ImageMagick 6 → 7**: validated by staging for the perl binding; check the
  shell scripts that call `convert` directly still work (IM7 keeps `convert` as a
  compatibility command).
* **`autoremove` after the trixie hop** removes apreq2 and the nginx modules
  (step 3): check both before starting apache.
* **mod_perl startup**: `conf/apache-2.4` is the production config, not the one
  staging uses (docker); this is the most likely place for a surprise — read
  `/var/log/apache2/error.log` first if apache does not answer.
* `gen_feeds_daily@opff` was **already failing** before the upgrade
  (`export_database.pl` refuses to replace a CSV more than 1% smaller than the
  previous one), don't count it as a regression. CSV exports are removed from
  `gen_feeds_daily.sh` by openfoodfacts/openfoodfacts-server#15055 (now made by
  `openfoodfacts-exports`). Because of this pre-existing failure, a new failure
  in `mongodb_dump.sh` does not change the unit's state: read the list of
  failed commands, not just "failed".
* **`mongodb-database-tools` must be reinstalled** (step 3): without them the
  public JSONL dumps are silently replaced by empty files, see the opff log.

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
* the network fixes of step 0: the stale interface stanza was only on opff,
  `systemd-networkd-wait-online` had to be disabled on opff, off-pro and opf;
  probably needed on obf and off too.
* **check ssh on off-pro**: the `openssh-server` upgrades disabled
  `ssh.service` on opf (step 3); off-pro was not checked
  (`systemctl is-enabled ssh`). opf has both `ssh.service` and `ssh.socket`
  enabled (as before the upgrade); Debian's default is the service only.
* **nginx `worker_connections 768`** (Debian's default, `/etc/nginx/nginx.conf`
  replaced by the package's since it was never modified) is too low for opf
  under crawler load: raise it (e.g. 4096) on every container, after the
  upgrade.
* **stale public dumps on opf**: `openproductfacts-*` files (old name, without
  the "s"), from February / April 2026, three of them 20-byte empty gzips, and
  a 67 GB `ocr.jsonl.gz` from August 2023, all in `/srv/opf/html/data/`: check
  nothing links to them and delete them.

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
* **regression found on 2026-10-21** (user report): the plan said to
  `apt purge mongodb-database-tools` (wrongly assuming nobody ran `mongodump`).
  From the night of 2026-10-16, `mongodb_dump.sh` failed with
  `mongoexport: command not found`; with no `pipefail`, `mongoexport | gzip`
  still "succeeded", so `openpetfoodfacts-products.jsonl.gz`,
  `…products_obsolete.jsonl.gz` and `…recent_changes.jsonl.gz` were replaced by
  20-byte empty gzips every night, while `openpetfoodfacts-mongodbdump.gz`
  stayed at 2026-10-15. Nobody noticed because `gen_feeds_daily@opff` was
  already failing on `export_database.pl`. Fixed by installing the Debian 12
  build of `mongodb-database-tools` 100.10.0 (now in step 3) and re-running
  `gen_feeds_daily@opff`: JSONL back to 18.8 MB. `pipefail` added to
  `mongodb_dump.sh` in openfoodfacts-server.

### off-pro (CT 112), 2026-10-20

Times (CEST):

| Time | Step |
| --- | --- |
| 17:30 → 17:34 | purge of the desktop packages + autoremove (site up) |
| ~17:38 | site stopped (step 1) |
| 17:40 | snapshot `zfs-hdd/pve/subvol-112-disk-0@pre-trixie_2026-10-20_1540` (`11.11`) |
| 17:48 → 17:58 | bullseye → bookworm (10 min) |
| 17:58 → 18:14 | bookworm → trixie (16 min) |
| 18:14 → 18:33 | perl modules, config review, reboot (18:25), checks: site up |

* no stale `eth10` stanza, `networking` was fine; `systemd-networkd-wait-online`
  disabled (no `.network` file).
* rootfs dataset has **no refquota** (the "30G" of the ansible definition does
  not apply), 20.9T available.
* purge: `evince yelp aptitude ansible` (+ `gnumeric-doc`) then autoremove of
  237 packages, ~850 MB in total. CPAN `.so` check (840 libraries, 37 XS
  modules) found no overlap; `ssconvert` round trip and the site OK after.
* extra apt repository `google-cloud-sdk.list`, kept (Carrefour image import
  uses `gcloud`); `google-cloud-cli` upgraded from 565 to 590 by the hops.
* `systemctl disable` of `producers_import@off-pro.timer` and
  `gen_feeds_daily@off-pro.timer` also deleted their links to
  `/srv/off-pro/conf/systemd/` (units added with `systemctl link`); restored from
  etckeeper with `git checkout HEAD -- systemd/system/<unit>`. Step 1 now only
  removes the `*.wants/` links.
* trixie `autoremove` removed `libapache2-request-perl`/`libapache2-mod-apreq2`
  (and `apreq2.load`) and the `libnginx-mod-*` modules; step 4's `apt install`
  brought apreq back and re-enabled it, the nginx config does not use the
  modules (`nginx -t` OK).
* cpm: all modules OK; `tz.sqlite3` converted.
* config review: the same files as opff, plus
  `fail2ban/jail.d/defaults-debian.conf.dpkg-dist` (deleted, see the table).
* leaving tmux with `exit` ran the commands still queued from a pasted block
  on scaleway-01 at 18:27, after the reboot: an extra snapshot
  `pre-trixie_2026-10-20_1627` of the upgraded system (destroyed) and
  `sync=disabled` again (restored). Hence `nohup` instead of tmux in the
  procedure.
* after reboot: no waiting job, all units active, same commit, site `200`, no
  perl/timezone/apreq error in the apache log.
* to do: functional tests (import, export, image crop), re-enable the instance
  timers and the apt timers, monitoring, check the next night's import.

### opf (CT 114), 2026-10-26

Times (CET):

| Time | Step |
| --- | --- |
| before 09:58 | step 0, purge of the desktop packages + autoremove (site up) |
| 09:59 | site stopped (step 1) |
| 10:00 | snapshot `zfs-hdd/pve/subvol-114-disk-0@pre-trixie_2026-10-26_0900` (`11.10`) |
| ~10:01 → 10:06 | bullseye → bookworm (5 min) |
| 10:06 → ~10:17 | bookworm → trixie |
| 10:17 → 10:25 | MongoDB tools check, perl modules, config review, reboot: site up |

* deployed code: v2.116.1; units like opff (`minion@`, `redis_listener@`,
  `cloud_vision_ocr@`, `gen_feeds_daily@` service + timer); only the
  `mongodb-org-4.4` third-party repository. Rootfs: no refquota, 30.1G used.
* no stale interface stanza, `networking` fine; `systemd-networkd-wait-online`
  disabled (empty `/etc/systemd/network/`).
* purge: same 5 packages as off-pro, then autoremove of 261 packages / 689 MB
  (the extra ones: ansible's python modules and aptitude's libraries). CPAN
  check (883 libraries, 36 XS modules) and python scripts check clean.
* the `curl` after the purge returned `500`: nginx alerts
  `768 worker_connections are not enough` at 09:43–09:50 under a distributed
  crawler (same facet pages from many IPs, fake referrer
  `world-ca.pro.openproductsfacts.org`); `fr.` and `world.` both `200` right
  after. Most likely not related to the upgrade.
* `gen_feeds_daily@opf.timer` has a drop-in
  (`/etc/systemd/system/gen_feeds_daily@.timer.d/override.conf`), unchanged by
  the upgrade (step 5 diff).
* **ssh**: `openssh-server` disabled `ssh.service` during the bookworm hop
  ("Synchronizing state of ssh.service with SysV service script … disable
  ssh"), and again during the trixie hop; it was enabled before
  (`ssh.service` and `ssh.socket` in `enabled-before.txt`). Re-enabled after
  the trixie hop (now in step 3); sshd listens on 22 after the reboot. rsyslog
  was only losing its obsolete `/etc/init.d/rsyslog` script, still enabled.
* trixie autoremove: 90 packages (IM6, perl 5.36, python 3.9/3.11, apreq,
  `libnginx-mod-*`, `geoip-database`, `usrmerge`…); the nginx config uses none
  of the modules, `nginx -t` OK. `mongodb-database-tools` 100.10.0 was still
  installed (no purge any more), `mongoexport`/`mongodump` OK.
* step 4: apreq reinstalled and enabled (its postinst tried an apache reload
  without the env file: "Port must be specified", harmless); cpm installed 169
  distributions, no FAIL; all modules OK; `tz.sqlite3` converted.
* config review: the same 14 files as off-pro, same decisions.
* after reboot (10:25): no waiting job, all units active, sshd on 22, same
  commit, site `200` (3 s for the first request), no perl/timezone/apreq error.
* timers (`gen_feeds_daily@opf`, next run 05:00) and apt timers re-enabled.
* to do: functional tests from outside, expire the Alertmanager silence if one
  was set, check the dumps of the night 2026-10-26 → 27 against
  `/root/dumps-before.txt` (40 MB JSONL, 46 MB MongoDB dump, not 20 bytes).
