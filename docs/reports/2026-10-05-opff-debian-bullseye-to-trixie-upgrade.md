# 2026-10-05 opff (CT 115) Debian bullseye → trixie upgrade

## Context

`opff` (container 115, on `scaleway-01`) serves <https://openpetfoodfacts.org>.
It is a Product Opener instance that was moved from `off2` in March 2026
([report](./2026-03-12-moving-opff-to-scaleway.md)) by cloning the old off2 rootfs,
so it is still running the original **Debian 11.10 (bullseye)**.

Debian 11 reached **end of life on 2026-08-31**
([Debian news](https://www.debian.org/News/2026/20260831)), so this container no
longer receives security updates.

The `scaleway` proxmox cluster runs proxmox-ve 9.2 on Debian 13, so any *new*
container created there is already trixie
([proxmox](../explanation/proxmox.md), `proxmox_containers` role picks
`debian-{{ distribution_major_version }}`).

Related reports to read first:

* [2026-09-14-ovh1-104-debian-upgrade.md](./2026-09-14-ovh1-104-debian-upgrade.md) — wiki, 11 → 12, in a container
* [2026-09-25-ovh2-107-matomo-upgrades.md](./2026-09-25-ovh2-107-matomo-upgrades.md) — 10 → 11 → 12, and the PVE / Debian version trap
* [2023-03-14-off2-opff-reinstall.md](./2023-03-14-off2-opff-reinstall.md) — the full opff install recipe (packages, cpanm, apache, nginx, systemd units)
* [how to deploy a new service](../how-to/how-to-deploy-a-new-service.md) — "separating data from the system" is exactly what makes this upgrade reversible

## Decisions

| Question | Answer |
| --- | --- |
| Method | in-place upgrade, one release at a time: **11 → 12 → 13** |
| Where | in a **blue/green clone** of CT 115 (CT 117 `opff-trixie`), never on the production CT |
| Cutover | **swap the rootfs dataset** under CT 115, so hostname (`opff`), IP (`10.13.1.115`) and reverse proxy config never change; no DNS change |
| Rollback | rename the datasets back and start the bullseye rootfs |
| Ansible | **not used**, neither before, during nor after (see [Why no ansible](#why-no-ansible)) |
| MongoDB | **stays on 4.4**, the server is not touched at all by this upgrade (see [MongoDB stays on 4.4](#mongodb-stays-on-44)) |
| Scope | opff only. `off` (111), `off-pro` (112), `obf` (113), `opf` (114) are clones of the same bullseye rootfs, see [Follow-ups](#follow-ups) |

## MongoDB stays on 4.4

The `MongoDB` perl driver required by Product Opener is pinned in the
[cpanfile](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/cpanfile)
to `>= 2.2.2, < 2.3`, and that driver only supports MongoDB servers up to
**4.4**. So:

* the MongoDB **server** (a container on `scaleway-docker-prod`, see
  [2026-01-15-moving-mongodb-to-scaleway.md](./2026-01-15-moving-mongodb-to-scaleway.md))
  stays on 4.4 and is **not** part of this upgrade
* opff only holds the perl driver (recompiled for perl 5.40) and, incidentally,
  the `mongodb-database-tools` client (`mongodump`, `mongorestore`) version
  100.10.0 installed from the mongodb 4.4 apt repo
* since that repo has **no build for bookworm or trixie** (MongoDB publishes
  8.0 for the `bookworm` component, and only `mongosh` for `trixie`), the repo is
  moved away during the upgrade and the tools are **not** replaced by 8.0 ones:
  staying on 4.4 tooling is the point
* nobody in this repo runs `mongodump`: MongoDB backups are ZFS dataset backups.
  If a logical dump is ever needed, run it on the MongoDB host, where the 4.4
  tools live

## Why no ansible

opff is declared in ansible (`ansible/inventory.production.ini`,
`ansible/host_vars/opff/`, `ansible/host_vars/scaleway-01/proxmox.yml`) but the
playbooks are **not** run against it: its mount points, network and service
configuration were all done by hand (see the March 2026 migration report, where
the containers playbook was deliberately skipped: *"I didn't use the configure
job"*).

So this upgrade must not run `jobs/configure.yml` nor
`sites/proxmox-node.yml --tags containers`: that would apply configuration
(base, fail2ban, iptables, nullmailer, molly-guard, unattended-upgrades
templates…) that opff has never had, mixing an infra migration into an OS
upgrade. Everything below is done by hand, like the previous opff installs.

## State verified on 2026-10-05

### Host `scaleway-01`

* `proxmox-ve: 9.2.0`, `pve-manager: 9.2.3`, kernel `6.17.2-2-pve`
* `/usr/share/perl5/PVE/LXC/Setup/Debian.pm` already knows `trixie/sid => 13`, so a Debian 13 container starts normally here
  (this is what broke matomo on ovh2, whose host was still on PVE 8)
* `local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst` already downloaded
* free space: `zfs-hdd` 21.2T, `zfs-nvme` 2.16T → ZFS clones of the data volumes are cheap
* sanoid snapshots `zfs-hdd/pve/subvol-115-disk-0@autosnap_*_hourly` every hour, `local_sys` policy (36 hourly, 10 daily)

### CT 115

```
arch: amd64              cores: 6        memory: 12288
features: nesting=1      onboot: 1       protection: 1     unprivileged: 1
mp0: /zfs-hdd/podata/opff,mp=/mnt/opff
mp1: /zfs-hdd/podata/opff/cache,mp=/mnt/opff/cache
mp2: /zfs-hdd/podata/opff/html_data,mp=/mnt/opff/html_data
mp3: /zfs-nvme/podata/products,mp=/mnt/opff/products
mp4: /zfs-hdd/podata/images,mp=/mnt/opff/images
mp5: /zfs-nvme/podata/users,mp=/mnt/opff/users
mp6: /zfs-nvme/podata/orgs,mp=/mnt/opff/orgs
net0: name=eth0,bridge=vmbr10,gw=10.13.0.1,hwaddr=BC:24:11:00:03:A5,ip=10.13.1.115/16,type=veth
rootfs: zfs-hdd-pve:subvol-115-disk-0,size=30G
lxc.idmap: u 0 100000 999 / u 1000 1000 64536  (same for g)
lxc.cap.drop: "sys_rawio audit_read"
```

* all opff data is **local ZFS on scaleway-01** now (the NFS mounts of the March 2026 migration are gone)
* `zfs-hdd/pve/subvol-115-disk-0`: 16.5G used (including snapshots), quota 30G

Inside the container:

| Item | Value |
| --- | --- |
| OS | Debian GNU/Linux 11 (bullseye), `/etc/debian_version` = `11.10` |
| apt sources | `ftp.debian.org` bullseye + bullseye-updates, `security.debian.org` bullseye-security, and `mongodb-org-4.4.list` |
| `apt update` | works (244 packages upgradable), even though bullseye is EOL |
| perl | 5.32.1 |
| nginx | 1.18.0 (apt, config symlinked from `/srv/opff/conf/nginx`) |
| apache2 | 2.4.61 (Debian), `mpm_prefork`, running as user `off`, listening on 8001, config symlinked from `/srv/opff/conf/apache-2.4`) |
| PHP | **not installed** (Product Opener is perl + mod_perl), so no PHP major upgrade to handle |
| enabled units | `apache2`, `nginx`, `cron`, `fail2ban`, `unattended-upgrades`, `redis_listener@opff`, `minion@opff`, `cloud_vision_ocr@opff`, `gen_feeds_daily@opff.timer` |
| `/etc/cron.d` | `e2scrub_all`, `geoipupdate`, `munin-node` |
| systemd drop-ins | `apache2.service.d/override.conf` (and `apache2@.service.d`), `nginx.service.d/override.conf`, `netfilter-persistent.service.d/{iptables,ipset}.conf` |
| units in git | `/srv/opff/conf/systemd/{minion@,redis_listener@,gen_feeds_daily@,email-failures@,cloud_vision_ocr@,producers_import@,prometheus-apache-exporter@}` |
| `/srv/opff` | git clone of `openfoodfacts/openfoodfacts-server`, owned by `off`, at commit **`f537513546f94f9ac3eb427ac8d76b07d74f9b8b`** (2026-09-25, release 2.109.0) |
| untracked in `/srv/opff` | `data`, `html/off_web_html`, `import_files`, `reverted_products`, `translate`, `scripts/export_database_nok.pl`, `scripts/migrations/test.pl` (symlinks to `/mnt/opff` + two local scratch files) — expected, compare with the same command after the upgrade |
| CPAN modules (outside Debian) | in `/usr/local/share/perl/5.32.1` (+ the matching arch dir) and `/usr/local/bin` (`mc`, `mojo`, `plackup`, `morbo`, `ocr`, `hypnotoad`, `checkdigits.pl`, …). `cpanm` itself comes from the Debian `cpanminus` package (`/usr/bin/cpanm`) |
| image toolchain | **ImageMagick 6.9.11-60 Q16** (`imagemagick`, `imagemagick-6.q16`, `libimage-magick-perl`, `libimage-magick-q16-perl`), `convert`/`identify` in `/bin`, plus `Imager` (cpan) |
| geoip | `geoip-database` (data from 2019), `geoipupdate` 4.6.0, `libgeoip1`, `libgeoip2-perl`, **`libnginx-mod-http-geoip`** and `libnginx-mod-stream-geoip` 1.18.0 (nginx geoip modules, Debian's data is stale but it is what we use) |
| other | `tesseract-ocr` 4.1.1, `graphviz` 2.42.2, `mongodb-database-tools` 100.10.0 (`/bin/mongodump`, `/bin/mongorestore`, from the mongodb 4.4 repo), `libbson-xs-perl` 0.8.4 |
| config in git (symlinks, fragile) | `/etc/apache2/ports.conf`, `/etc/apache2/sites-enabled/opff.conf`, `/etc/nginx/mime.types`, `/etc/nginx/sites-enabled/{opff,default}`, 8 files in `/etc/nginx/snippets/` (plus 2 package files, `fastcgi-php.conf` and `snakeoil.conf`) |
| already failing on 115 | `gen_feeds_daily@opff.service` → `export_database.pl` exits 1 (fails daily, see [Follow-ups](#follow-ups)), `networking.service`, `ifupdown-wait-online.service` (**pre-existing**, not upgrade related) |

### What the cpanfile requires (this is what has to be rebuilt for perl 5.40)

From [openfoodfacts-server/cpanfile](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/cpanfile)
at release 2.109.0, the modules that are **not** available as sane Debian
packages, or that are pinned, are the real work of this upgrade:

| Module | Why it matters |
| --- | --- |
| `MongoDB` `>= 2.2.2, < 2.3` | XS, pinned: Debian only has 1.8.1/2.0.3, this is the driver used for everything |
| `Type::Tiny::XS` `== 0.025` | XS, pinned, and `==` means cpanm will insist on that exact old version |
| `CGI` `== 4.70` | pinned |
| `Crypt::JWT` `== 0.035` | pinned (OIDC) |
| `GS1::SyntaxEngine::FFI` | XS + FFI, needed by the new GS1 Sunrise 2027 code |
| `Imager`, `Imager::zxing`, `Imager::File::{AVIF,HEIF,JPEG,PNG,WEBP}` | XS, needs `libheif-dev`, `libwebp-dev`, `libjpeg-dev`, `libpng-dev` to build |
| `Image::Magick` | comes from `libimage-magick-perl`, which is **IM7** in trixie |
| `GeoIP2`, `OIDC::Lite`, `Minion`, `Mojolicious`, `AnyEvent::RipeRedis`, `Text::CSV` `>= 2.01, < 3.0`, `Locale::Unicode == 0.4.4`, `DateTime::Lite == 0.9.0` | pure perl, reinstalled from CPAN |

Two consequences:

* reinstalling from the cpanfile will fetch **newer CPAN versions** than the ones
  running today (nothing is pinned to today's version), so we record them first
* some of those old pinned XS modules may fail to compile against perl 5.40; a
  cpanm failure is not automatically fatal, but whatever failed must be checked
  against what the site actually uses

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| bullseye is EOL since 2026-08-31, last packages may 404 | the 11 → 12 hop fails | fully `apt full-upgrade` on bullseye **first** (repos still answer); if 404s appear, temporarily use `archive.debian.org` |
| perl 5.32 → 5.36 → 5.40, and the CPAN modules live in the version-specific dirs `/usr/local/share/perl/5.32.1` and `/usr/local/lib/*/perl5/5.32.1` | opff display / API / feeds break | move those dirs aside and reinstall from `/srv/opff/cpanfile` after **each** hop |
| pinned/old XS modules (`MongoDB 2.2.2`, `Type::Tiny::XS 0.025`, `CGI 4.70`, `Crypt::JWT 0.035`, `GS1::SyntaxEngine::FFI`) may not compile against perl 5.40 | missing driver = site down | capture the cpanm output, and check what failed against actual usage; `MongoDB` is the one that must work |
| reinstalling from the cpanfile pulls **newer CPAN versions** than today | behaviour change unrelated to the OS upgrade | record the installed versions before (phase 0) and diff after |
| **ImageMagick 6 → 7** (trixie only ships IM7, `libimage-magick-perl` becomes IM7-based, `convert` may become `magick`) | image resize / stamp / barcode pipelines break | baseline `dpkg -L imagemagick \| grep bin/` now, re-check after the 12 → 13 hop, test a real image operation, and if `Image::Magick` misbehaves discuss with the Product Opener team |
| tesseract 4 → 5, graphviz 2.42 → newer | OCR / graph rendering | used through `Image::OCR::Tesseract` and `GraphViz2`; test after the hop |
| nginx geoip: `libgeoip1` → `libgeoip1t64` in trixie, and `geoip-database` data was reverted to Dec 2019 | `nginx -t` fails if `geoip_*` directives lose their module | check whether `/srv/opff/conf/nginx` uses `geoip` directives (phase 0), then `nginx -t` after each hop |
| dpkg overwrites config files that are symlinks into `/srv/opff/conf` with package defaults | apache/nginx silently revert to defaults | re-create the symlinks after each hop, then `apache2ctl configtest` and `nginx -t` |
| `mongodb-org 4.4` repo has no bookworm/trixie build, so `mongodb-database-tools` 100.10.0 is removed | we do **not** want the 8.0 tools either, the perl driver only supports a 4.4 server | purge the tools and leave the repo out, see [MongoDB stays on 4.4](#mongodb-stays-on-44); dumps are done on the MongoDB host |
| rootfs has a 30G quota, shared between the origin, its snapshots and the clone | ENOSPC in the middle of the upgrade | check `zfs get quota,refquota,used` on the host first, raise the clone quota or enlarge the rootfs if needed |
| `unattended-upgrades` is enabled with `Automatic-Reboot "true"` | surprise reboot mid-upgrade | stop and disable it for the whole operation, re-enable after |
| the test instance shares prod MongoDB / PostgreSQL / Redis | test edits change prod data, minion/redis_listener process events twice | keep the test instance read-only, disable `minion`, `cloud_vision_ocr`, `redis_listener`, `gen_feeds*` in it |
| proxmox too old for Debian 13 (bit ovh2 in Sept 2026) | container does not start | **verified OK**: scaleway-01 is proxmox-ve 9.2.0, `Debian.pm` knows trixie |
| `gen_feeds_daily@opff` already failing (`export_database.pl`) | cannot tell afterwards if the upgrade broke it | investigate and record the baseline before touching anything (separate bug, see [Follow-ups](#follow-ups)) |

## Tasks

### Phase 0 — last investigation before touching anything

Most of the inventory is done (see [State verified on 2026-10-05](#state-verified-on-2026-10-05)).
What is still needed:

```bash
# --- in CT 115 (root), read only ---

# 1. baseline of the imagemagick binaries, to compare with trixie's IM7
dpkg -L imagemagick imagemagick-6.q16 | grep bin/
convert -version | head -3

# 2. does the nginx config use the geoip module? (trixie renames libgeoip1 -> libgeoip1t64)
grep -rn "geoip" /srv/opff/conf/nginx/ | head -20
ls -l /usr/share/GeoIP/ 2>/dev/null

# 3. version of every module the cpanfile requires, this is the reference
#    we diff against after the reinstall (Module::Metadata is core perl)
cd /srv/opff
sudo -u off perl -e '
  require Module::Metadata;
  my @mods;
  open my $fh, "<", "cpanfile" or die $!;
  while (my $l = <$fh>) { push @mods, $1 if $l =~ /^\s*requires\s+.(.:[\w:]+)./ }
  for my $m (sort @mods) {
    my $meta = eval { Module::Metadata->new_from_module($m) };
    printf "%-38s %s\n", $m, ($meta ? ($meta->version // "unknown") : "MISSING");
  }' | tee /root/perl-modules-bullseye.txt

# 4. build dependencies that Imager / GS1::SyntaxEngine::FFI will need later
dpkg -l | grep -E "libheif-dev|libwebp-dev|libjpeg.*-dev|libpng-dev|build-essential|libperl-dev"

# 5. the pre-existing gen_feeds_daily failure (export_database.pl), for the record
journalctl -u gen_feeds_daily@opff.service -n 100 --no-pager | tail -40
grep -rn "mongodump\|export_database" /srv/opff/scripts/gen_feeds_daily.sh

# 6. baselines for later comparison
dpkg-query -W -f='${binary:Package}\t${Version}\n' | sort > /root/dpkg-bullseye.tsv
apt-mark showmanual | sort > /root/apt-manual-bullseye.txt
```

```bash
# --- on scaleway-01, read only (zfs is not available inside the container) ---
zfs get quota,refquota,used,referenced zfs-hdd/pve/subvol-115-disk-0
zfs list -t snapshot -o name,used,refer zfs-hdd/pve/subvol-115-disk-0 | tail -5
```

Also record, from monitoring or locally, the prod baseline: response times of
`https://world.openpetfoodfacts.org/`, `.../api/v2/product/3017620422002`,
CPU/memory of the container.

### Phase 1 — preparation

- [ ] pick the maintenance window (cutover itself is ~5 min, see [Phase 7](#phase-7--cutover))
- [ ] announce it (chat/mail), and note that no DNS change is needed
- [ ] confirm the hourly sanoid snapshot of the rootfs is recent, and that syncoid pushes `zfs-hdd/pve` to ovh3:
      `zfs list -t snapshot zfs-hdd/pve/subvol-115-disk-0 | tail -2`
- [ ] confirm CT 117 is free on all scaleway nodes: `pct list | grep -E '116|117'` (116 is `scaleway-images-tmp` on scaleway-03) and that `10.13.1.117` is unused

### Phase 1b — take an extra snapshot of the system disk

The hourly sanoid snapshots are for backups and get pruned; before touching
anything we take our own snapshot of the opff system disk, with a name sanoid
will not recognise (same convention as the clones in
[2024-12-03 report](./2024-12-03-create-container-for-open-food-supplements-facts.md),
so sanoid does not delete it behind our back).

```bash
# on scaleway-01
SNAP=pre-trixie-upgrade_$(date --utc +"%Y-%m-%d_%H:%M:%S")
zfs snapshot zfs-hdd/pve/subvol-115-disk-0@$SNAP
echo $SNAP    # keep the name for the rollback section

# verification
zfs list -t snapshot -o name,used,refer,creation zfs-hdd/pve/subvol-115-disk-0 | tail -5
```

Notes:

* do **not** stop the container for this, a ZFS snapshot is atomic and online
* this snapshot is the fallback if something goes wrong before or during the
  cutover: `zfs rollback zfs-hdd/pve/subvol-115-disk-0@$SNAP`
* it is also the cleanest snapshot to clone CT 117 from, since it is taken at a
  known point in time (the clone snapshot of phase 2 is taken a few minutes
  later, from the same origin)
* the data volumes (`zfs-hdd/podata/*`, `zfs-nvme/podata/*`) do not need an
  extra snapshot: they are never modified by this operation (the test instance
  works on `-trixie` clones) and sanoid snapshots them hourly
* destroy it in [phase 8](#phase-8--cleanup-a-few-days-later) once the trixie
  container has proven itself for a while

### Phase 2 — build the blue/green container CT 117

Done **offline** (container stopped) so we never have two containers with the
production IP.

```bash
# on scaleway-01
TAG=opff-trixie_$(date --utc +"%Y-%m-%d_%H:%M:%S")

# 1. snapshot + clone the rootfs
#    do NOT use an autosnap_* name, sanoid would prune it (cf. 2024-12-03 report)
zfs snapshot zfs-hdd/pve/subvol-115-disk-0@clone-for-117_$TAG
zfs clone zfs-hdd/pve/subvol-115-disk-0@clone-for-117_$TAG zfs-hdd/pve/subvol-117-disk-0

# 2. snapshot + clone the data volumes (-R keeps opff/cache and opff/html_data)
for ds in zfs-hdd/podata/opff zfs-hdd/podata/images zfs-nvme/podata/products \
          zfs-nvme/podata/users zfs-nvme/podata/orgs; do
  zfs snapshot $ds@$TAG
  zfs clone -R $ds@$TAG ${ds}-trixie
done

zfs list -o name,used,refquota | grep -E '117|trixie'
```

Then create the config from CT 115:

```bash
cp /etc/pve/lxc/115.conf /etc/pve/lxc/117.conf
```

Edit `/etc/pve/lxc/117.conf`:

- `hostname: opff-trixie`
- `hwaddr:` a new MAC (not `BC:24:11:00:03:A5`)
- `ip=10.13.1.117/16`
- `rootfs: zfs-hdd-pve:subvol-117-disk-0,size=30G`
- `onboot: 0` — this container must never start by itself
- `mp0:` … `mp6:` all point to the `-trixie` datasets

Then fix the clone offline (`ROOT=/zfs-hdd/pve/subvol-117-disk-0`):

```bash
ROOT=/zfs-hdd/pve/subvol-117-disk-0

# hostname and IP
echo opff-trixie > $ROOT/etc/hostname
sed -i 's/10\.13\.1\.115/10.13.1.117/' $ROOT/etc/network/interfaces
sed -i 's/\bopff\b/opff-trixie/g' $ROOT/etc/hosts

# apache2 reads its environment from /srv/%l/env/env.%l (%l = short hostname)
mkdir -p $ROOT/srv/opff-trixie/env
ln -s /srv/opff/env/env.opff $ROOT/srv/opff-trixie/env/env.opff-trixie
chown -R off:off $ROOT/srv/opff-trixie

# services that must not run twice while prod runs
cd $ROOT/etc/systemd/system/multi-user.target.wants
rm -f cloud_vision_ocr@opff.service minion@opff.service redis_listener@opff.service \
      gen_feeds@opff.timer gen_feeds_daily@opff.timer

pct start 117
pct enter 117

# belt and braces while testing
systemctl mask minion@opff.service cloud_vision_ocr@opff.service redis_listener@opff.service \
                  gen_feeds@opff.timer gen_feeds_daily@opff.timer
```

Check the clone works before upgrading anything:

```bash
systemctl list-units --failed --no-pager
systemctl status apache2 nginx --no-pager
apache2ctl configtest; nginx -t
curl -sS -o /dev/null -w '%{http_code}\n' -H 'Host: world.openpetfoodfacts.org' http://127.0.0.1/cgi/display.pl
```

### Phase 3 — 11 → 12 (bookworm) in CT 117

```bash
# 0. nothing should touch apt during the operation
systemctl stop unattended-upgrades
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer

# 1. clean starting point
dpkg --audit; apt-mark showhold

# 2. bring bullseye fully up to date first (repos still answer)
apt update && apt full-upgrade
apt list --upgradable            # must be empty before switching sources
apt autoremove --purge           # read the list before confirming

# 3. switch sources to bookworm, keeping the old ones for rollback
mv /etc/apt/sources.list /etc/apt/sources.list.bullseye
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

# 4. mongodb-org 4.4 has no bookworm build, and we want to stay on 4.4 anyway
#    (see "MongoDB stays on 4.4"), keep apt happy
mv /etc/apt/sources.list.d/mongodb-org-4.4.list /root/
apt update

# 5. upgrade, step by step
apt upgrade --without-new-pkgs          # add --fix-missing if packages 404
apt full-upgrade
apt autoremove --purge

# 6. packages no longer covered by Debian
apt install debian-security-support
check-support-status                   # then purge what it reports
```

**perl 5.32 → 5.36.** The cpanm modules were installed for perl 5.32 and live in
the version-specific site directories, so they must be moved aside and
reinstalled:

```bash
# what perl considers its site directories right now
perl -V | grep -E '^(site|priv|arch|vendor)'

# move the 5.32.1 ones aside (both the pure perl and the arch one)
mv /usr/local/share/perl/5.32.1 /usr/local/share/perl/5.32.1.bullseye
mv /usr/local/lib/*/perl5/5.32.1 /usr/local/lib/*/perl5/5.32.1.bullseye
# /usr/local/bin keeps the perl scripts (mc, mojo, plackup, ocr…): they only
# need the modules back, no need to move them

# build dependencies for the XS modules, then reinstall from the cpanfile
apt install build-essential libperl-dev libheif-dev libwebp-dev libjpeg-dev libpng-dev
cd /srv/opff && sudo cpanm --notest --quiet --skip-satisfied --installdeps . \
  | tee /root/cpanm-bookworm.log
grep -iE "^Fail|! Install" /root/cpanm-bookworm.log    # what failed, if anything

# diff the module versions against the phase 0 baseline
sudo -u off perl -e '
  require Module::Metadata;
  my @mods;
  open my $fh, "<", "cpanfile" or die $!;
  while (my $l = <$fh>) { push @mods, $1 if $l =~ /^\s*requires\s+.(.:[\w:]+)./ }
  for my $m (sort @mods) {
    my $meta = eval { Module::Metadata->new_from_module($m) };
    printf "%-38s %s\n", $m, ($meta ? ($meta->version // "unknown") : "MISSING");
  }' > /root/perl-modules-bookworm.txt
diff /root/perl-modules-bullseye.txt /root/perl-modules-bookworm.txt
```

Anything reported `MISSING` or newly installed at a much newer version is
expected (the cpanfile pins minimums, not current versions) and is **not** a
regression: what matters is `MISSING`, and whether `MongoDB`, `Imager`,
`Image::Magick`, `OIDC::Lite` and `Minion` load.

```bash
cd /srv/opff
for m in MongoDB Imager Image::Magick Minion Mojolicious OIDC::Lite GeoIP2 GS1::SyntaxEngine::FFI; do
  sudo -u off perl -M$m -e "print \"$m \", \$${m}::VERSION // 'ok', \"\n\"" 2>&1 | tail -1
done
```

**Restore the git-managed configuration** (dpkg does not follow our symlinks,
so it happily replaces them with package defaults):

```bash
ls -l /etc/apache2/sites-enabled/ /etc/apache2/ports.conf \
      /etc/nginx/sites-enabled/ /etc/nginx/snippets/ /etc/nginx/mime.types \
      /etc/systemd/system/*.d/
# re-create what was clobbered, from /srv/opff/conf/{apache-2.4,nginx,systemd}
# as done in 2023-03-14-off2-opff-reinstall.md
apache2ctl configtest && nginx -t && systemctl daemon-reload
systemctl restart apache2 nginx
```

Other files to review when dpkg asks: `/etc/sudoers`,
`/etc/apache2/{ports.conf,envvars,mods-available/*}`, `/etc/logrotate.d/*`,
`/etc/default/*`, `/etc/mailname`, `/etc/exim4/*`, `/etc/munin/*`,
`/etc/fail2ban/jail.conf` + `jail.d/*`, `/etc/ldap/*` if any.

Then reboot into bookworm and validate:

```bash
reboot
# after pct start again, from the host if needed
cat /etc/debian_version
systemctl --failed
systemctl is-enabled apache2 nginx cron fail2ban
curl -sS -o /dev/null -w '%{http_code}\n' -H 'Host: world.openpetfoodfacts.org' http://127.0.0.1/
```

### Phase 4 — 12 → 13 (trixie) in CT 117

Same procedure, sources become `trixie trixie-updates` + `trixie-security`.
Extra expectations:

- **perl 5.36 → 5.40**: move the site dirs aside and reinstall again, exactly as
  in phase 3 (`mv /usr/local/share/perl/5.36.1{,.bookworm}`,
  `mv /usr/local/lib/*/perl5/5.36.1{,.bookworm}`), then diff the module versions
  against `/root/perl-modules-bookworm.txt`
- **ImageMagick 6 → 7**: this is the biggest surprise of trixie. Debian 13 only
  ships IM7 (`imagemagick-7.q16`), and `libimage-magick-perl` becomes IM7-based.
  ```bash
  # compare with the phase 0 baseline
  dpkg -L imagemagick imagemagick-7.q16 | grep bin/
  which convert magick identify
  convert -version | head -3
  dpkg -l | grep -i imagemagick
  # and the two perl bindings PO actually uses
  cd /srv/opff && sudo -u off perl -MImage::Magick -e 'print $Image::Magick::VERSION, "\n"'
  ```
  if `convert` disappeared, Product Opener's image code (resize, stamp,
  thumbnails) may need the `magick` command; that is a code change, so stop here
  and discuss with the Product Opener team rather than working around it
- **t64 transition**: `libssl3t64`, `libpq5t64`, `libgeoip1t64`, … handled by
  dpkg, expect a lot of output
- **nginx geoip**: `libnginx-mod-http-geoip` now depends on `libgeoip1t64`, and
  `geoip-database` was reverted to a December 2019 dataset (Debian 13.6 release
  notes). If phase 0 showed `geoip_*` directives in
  `/srv/opff/conf/nginx`, run `nginx -t` and check the country redirect still
  works, otherwise consider dropping the directives
- **tesseract 4 → 5**: used through `Image::OCR::Tesseract`; test `tesseract --version`
  and one OCR run
- **systemd 252 → 257**: check the drop-ins still load, `systemd-analyze verify`
  on our units if something looks off
- **nginx 1.22 → 1.26** and **apache 2.4.62 → 2.4.65**: `nginx -t`, `apache2ctl configtest`
- **fail2ban 1.0.2 → 1.1.0**: `fail2ban-client status`, and check the jails we
  configured still ban

```bash
reboot
# then, from the host: the container must come back on proxmox 9
pct start 117 && pct enter 117
cat /etc/debian_version      # 13.x
systemctl --failed
```

### Phase 5 — post-upgrade repairs

- [ ] **mongodb tools**: `mongodb-database-tools` 100.10.0 was removed during the
      upgrade (the 4.4 repo has no bookworm/trixie build). We deliberately do
      **not** put the 8.0 tools in, see
      [MongoDB stays on 4.4](#mongodb-stays-on-44). Purge the leftovers and leave
      the repo out:
      ```bash
      apt purge mongodb-database-tools
      apt autoremove --purge
      # no /etc/apt/sources.list.d/mongodb-org-*.list is added back
      ```
      if somebody really needs a 4.4 logical dump, they run `mongodump` on the
      MongoDB host (`scaleway-docker-prod`), not here
- [ ] **mongodb driver**: the perl driver was recompiled for perl 5.40, check it
      still talks to the 4.4 server:
      ```bash
      grep -nE "mongodb_host|database_name" /srv/opff/lib/ProductOpener/Config2.pm | head
      cd /srv/opff && sudo -u off perl -Ilib -MConfig2 -e '
        my $c = MongoDB->new(host => $Config2::mongodb_host // "10.13.1.200");
        my $db = $c->database("opff");
        print "server version: ", $db->run_command([{ buildinfo => 1 }])->{version}, "\n";
        print "products: ", $db->collection("product")->estimated_document_count, "\n";'
      ```
      it must print `4.4.x`; if the driver fails to connect or reports a wire
      protocol error, stop here
- [ ] **geoipupdate**: still in trixie; check the cron job works and the country
      detection still resolves (`/etc/geoipupdate.conf` license key, `/var/lib/GeoIP`).
      Note the Debian `geoip-database` package is only good for a December 2019
      dataset, the real data comes from the `geoipupdate` cron job
- [ ] **munin-node / e2scrub**: `/etc/cron.d` untouched, just verify they still run
- [ ] **product opener**: `sudo -u off git -C /srv/opff log -1 --format='%H %ci %s'`
      is still `f537513546f94f9ac3eb427ac8d76b07d74f9b8b`, and
      `git status --short` still lists only the 7 known untracked entries
- [ ] **packages**: `diff /root/dpkg-bullseye.tsv <(dpkg-query -W -f='${binary:Package}\t${Version}\n' | sort)`
      and read the removals (`comm -23` on the package names), they should be
      explained by the two upgrades
- [ ] re-enable `unattended-upgrades` and the apt timers
      (`systemctl enable --now unattended-upgrades apt-daily.timer apt-daily-upgrade.timer`)

### Phase 6 — validation of CT 117

`10.13.1.117` is a private address in the Scaleway bay: it is only reachable from
a host inside that network, **not** from your workstation. Two ways to test.

#### Option A — command line checks, from a host inside the bay

This is enough for status codes, timings and payload checks, and is what phases 2
to 5 already use. Run it on `scaleway-01` itself, or on any host that routes to
`10.13.1.0/16`:

```bash
# 115 = production (bullseye), 117 = the trixie test instance
for ip in 10.13.1.115 10.13.1.117; do
  echo "== $ip"
  curl -sS -o /dev/null -w 'display.pl  %{http_code} %{time_total}s\n' \
       -H 'Host: world.openpetfoodfacts.org' http://$ip/cgi/display.pl
  curl -sS -o /dev/null -w 'front page %{http_code} %{time_total}s\n' \
       -H 'Host: world.openpetfoodfacts.org' http://$ip/
  curl -sS -o /dev/null -w 'api v2     %{http_code} %{time_total}s\n' \
       -H 'Host: world.openpetfoodfacts.org' \
       http://$ip/api/v2/product/3017620422002
done

# compare the payloads, they should be identical modulo timestamps
diff <(curl -sS -H 'Host: world.openpetfoodfacts.org' http://10.13.1.115/api/v2/product/3017620422002) \
     <(curl -sS -H 'Host: world.openpetfoodfacts.org' http://10.13.1.117/api/v2/product/3017620422002)
```

#### Option B — browser checks, through an SSH tunnel

Your workstation reaches the bay through the proxmox host (the same jump host
ansible uses, `config-op@scaleway-01`). Forward the container's port 80 to a
local port:

```bash
# on your workstation, keep it running in its own terminal
ssh -J config-op@scaleway-01 -N -L 8080:10.13.1.117:80 config-op@scaleway-01
```

then, **on your workstation**, point the real hostnames at the tunnel in
`/etc/hosts`:

```
127.0.0.1 world.openpetfoodfacts.org fr.openpetfoodfacts.org uk.openpetfoodfacts.org \
            static.openpetfoodfacts.org images.openpetfoodfacts.org
```

and browse `http://world.openpetfoodfacts.org:8080/` (nginx matches the server
name on the `Host` header, which does not include the port).

Caveats:

* inside the container nginx serves plain HTTP only (the `ssl` section was
  removed from `/srv/opff/conf/nginx`), so anything relying on a secure cookie
  (login) may not work through this tunnel
* while these `/etc/hosts` entries are in place, the real
  `openpetfoodfacts.org` is **not** reachable from your workstation; remove them
  as soon as you are done
* a full HTTPS + login test is only really possible after the cutover, which is
  why the rollback must be ready before starting phase 7

Adding a temporary test hostname on `scaleway-proxy` is **not** a good idea:
Product Opener derives the instance (off/opf/opff) from the `Host` header, and
redirects and cookies would send the browser back to the production domain.

Checks to perform:

- [ ] front page, search, a product page, a tag page, login page
- [ ] images: a resized product image and a full size one (this is the ImageMagick risk)
- [ ] API read: `/api/v2/product/3017620422002`
- [ ] compare status codes and response times against `10.13.1.115`
- [ ] `systemctl --failed` shows nothing new
- [ ] `/etc/systemd/system/*.d/` drop-ins and `/srv/opff/conf/systemd` timers are intact
- [ ] `journalctl -p err -b` reviewed
- [ ] **do not** run `gen_feeds`, minion jobs, uploads or product edits: MongoDB,
      PostgreSQL and Redis are the production ones. The only writes should be to
      the cloned datasets.

### Phase 7 — cutover

Goal: prod keeps the same CT id, hostname and IP, only the rootfs changes.

```bash
# on scaleway-01
pct shutdown 115
pct shutdown 117

# safety snapshot of the current prod rootfs (on top of the hourly sanoid ones)
zfs snapshot zfs-hdd/pve/subvol-115-disk-0@pre-cutover-trixie_$(date --utc +"%Y-%m-%d_%H:%M:%S")

# put the identity back into the trixie rootfs, offline
ROOT=/zfs-hdd/pve/subvol-117-disk-0
echo opff > $ROOT/etc/hostname
sed -i 's/opff-trixie/opff/g' $ROOT/etc/hosts
sed -i 's/10\.13\.1\.117/10.13\.1\.115/' $ROOT/etc/network/interfaces
rm -rf $ROOT/srv/opff-trixie              # the hostname hack is not needed anymore
cat $ROOT/etc/mailname                     # check it still says opff…

# swap the datasets
zfs rename zfs-hdd/pve/subvol-115-disk-0 zfs-hdd/backups/subvol-115-disk-0-bullseye-2026-10-05
pct destroy 117 --purge 1                 # removes the config, keeps the data
zfs rename zfs-hdd/pve/subvol-117-disk-0 zfs-hdd/pve/subvol-115-disk-0

# point CT 115 back at the production data volumes
#   (mp0..mp6 in /etc/pve/lxc/115.conf: drop the -trixie suffix)
pct start 115
```

Immediately after, in CT 115:

```bash
cat /etc/debian_version; hostname; ip -4 -br addr show eth0
systemctl --failed
systemctl is-enabled apache2 nginx cron fail2ban minion@opff redis_listener@opff \
                           cloud_vision_ocr@opff gen_feeds@opff.timer gen_feeds_daily@opff.timer
apache2ctl configtest; nginx -t
curl -sS -o /dev/null -w '%{http_code}\n' -H 'Host: world.openpetfoodfacts.org' http://127.0.0.1/
```

And from outside: <https://openpetfoodfacts.org>, <https://world.openpetfoodfacts.org>,
an image URL, the API, and the monitoring dashboards (response times, 5xx).

### Rollback

```bash
pct shutdown 115
zfs rename zfs-hdd/pve/subvol-115-disk-0 zfs-hdd/pve/subvol-117-disk-0-trixie-failed
zfs rename zfs-hdd/backups/subvol-115-disk-0-bullseye-2026-10-05 zfs-hdd/pve/subvol-115-disk-0
pct start 115
```

The production data volumes were never touched by the test instance (it worked on
`-trixie` clones), so no data rollback is needed. If the old rootfs is
irremediably broken, fall back on the extra snapshot of
[phase 1b](#phase-1b--take-an-extra-snapshot-of-the-system-disk):

```bash
pct shutdown 115
zfs destroy zfs-hdd/pve/subvol-115-disk-0          # if it is a clone, destroy the clone first
zfs rename zfs-hdd/backups/subvol-115-disk-0-bullseye-2026-10-05 zfs-hdd/pve/subvol-115-disk-0
zfs rollback zfs-hdd/pve/subvol-115-disk-0@pre-trixie-upgrade_<date>
pct start 115
```

### Phase 8 — cleanup (a few days later)

```bash
zfs destroy -r zfs-hdd/podata/opff-trixie
zfs destroy -r zfs-hdd/podata/images-trixie
zfs destroy -r zfs-nvme/podata/products-trixie
zfs destroy -r zfs-nvme/podata/users-trixie
zfs destroy -r zfs-nvme/podata/orgs-trixie
# remove the clone snapshots on the origins
for ds in zfs-hdd/pve/subvol-115-disk-0 zfs-hdd/podata/opff zfs-hdd/podata/images \
          zfs-nvme/podata/products zfs-nvme/podata/users zfs-nvme/podata/orgs; do
  zfs destroy $(zfs list -t snapshot -o name -s 1 "$ds" | grep opff-trixie)
done
```

- [ ] verify sanoid is happy again on `zfs-hdd/pve` and `zfs-hdd/podata`
- [ ] keep `zfs-hdd/backups/subvol-115-disk-0-bullseye-2026-10-05` for ~2 weeks
      (`local_data` policy snapshots it daily), then `zfs destroy -r` it
- [ ] once the bullseye copy is gone, destroy the extra system disk snapshot:
      `zfs destroy zfs-hdd/pve/subvol-115-disk-0@pre-trixie-upgrade_<date>`
- [ ] remove `/etc/pve/lxc/117.conf` leftovers if any (`pct list | grep 117`)

### Phase 9 — repository and documentation

- [ ] this report, updated with what actually happened (the repo convention is a
      report written as the work is done, see
      [2026-09-14-ovh1-104-debian-upgrade.md](./2026-09-14-ovh1-104-debian-upgrade.md))
- [ ] add `trixie # Debian 13` to the platform lists of
      `ansible/roles/base/meta/main.yml` and `ansible/roles/sshd/meta/main.yml`
      (cosmetic: opff is not managed by ansible, but the lists should not claim
      Debian 13 is unknown)
- [ ] optionally add the "proxmox version must know the Debian version" pitfall
      to [proxmox](../explanation/proxmox.md#some-errors)

## Follow-ups

- **separate bug, not part of this upgrade**: `gen_feeds_daily@opff.service` fails
  every day, `export_database.pl` exits 1 after ~2min30 of CPU. Found on
  2026-10-05 (last run 02:17 CEST) while investigating this upgrade, so the opff
  daily export feeds are broken on production. Worth its own report; do not
  confuse its failure with a regression after the upgrade (compare against the
  baseline captured in phase 0).
- `off` (111), `off-pro` (112), `obf` (113) and `opf` (114) are clones of the same
  bullseye rootfs and are still EOL. The same procedure applies; `off` (160 GB
  RAM, 50 cores, the main site) deserves its own window.
- the ansible declaration of opff (`inventory.production.ini`,
  `host_vars/scaleway-01/proxmox.yml`) does not match reality (mount points,
  network and services were configured by hand). Either reconcile it or document
  that opff is not ansible-managed, so nobody runs a playbook on it by accident.
- `geoip-database` is only good for a December 2019 dataset in every Debian
  release; the up-to-date data comes from the `geoipupdate` cron job and its
  MaxMind licence key. Worth checking that the licence is still valid.
- two scratch files live untracked in the openfoodfacts-server checkout
  (`scripts/export_database_nok.pl`, `scripts/migrations/test.pl`); they should
  not survive a `git clean`.
- MongoDB must stay on 4.4 until Product Opener ships a driver that supports a
  newer server (`MongoDB` perl driver `2.2.x` is the limit, it is pinned in the
  cpanfile). Upgrading the MongoDB container is a separate project.

## Log

<!-- to be filled while doing the work -->