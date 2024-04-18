# 2024-04-18 Matomo multi archival

After [dealing with queue problems](./2024-02-13-matomo-fix-queue0.md) we now have the reports that does not seems to generate well.

see [issue Matomo is still misreporting the website visits #108 ](https://github.com/openfoodfacts/openfoodfacts-monitoring/issues/108)

## Diagnosis

I spotted two problems:
* the timer is using OnUnitInactiveSec for the timer instead of OnUnitActiveSec,
  this means that our service run for 5h, then timeout, and then we wait again for 6h before restarting.
  While the plan is to run for at most 5h and then restart every 6h (so 1h wait max).
  I will even put the timeout to 5h50
* we only use one archiving process, we might use more…

## Proposal

My plan is to create different archiving tasks (using @ suffix of systemd).
Each task will have specific parameters thanks to a specific environmentFile= directive,
environment files can be shared in /etc/matomo with the format /etc/matomo/archive-<name>.env

## Doing it

I removed the old services and timers:

```bash
systemctl stop matomo-archive.timer
systemctl stop matomo-archive.service
systemctl disable matomo-archive.timer
unlink /etc/systemd/system/matomo-archive.timer
unlink /etc/systemd/system/matomo-archive.service
systemctl daemon-reload
```

Meanwhile I had prepared my env files and new services and timers.
([see commit 305c018767 feat: multiple matomo archiver](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/305c018767bcb46ecabed0009f893bd20f7ae867))

Now I just have to install them:
```bash
# create configurations
ln -s /opt/openfoodfacts-infrastructure/confs/matomo/matomo/archive-*.env  /etc/matomo/
ln -s /opt/openfoodfacts-infrastructure/confs/matomo/systemd/matomo-archive@.*  /etc/systemd/system
systemctl daemon-reload
# install
systemctl enable --now matomo-archive@main.timer matomo-archive@2.timer matomo-archive@5.timer
```