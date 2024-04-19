# 2023-06-30 Sanoid checks install

## Goal

Be able to monitor if sanoid is running correctly, by running a regular check.

## Creating check

I created and tested sanoid_check.sh

I then created the systemd unit and timer.

## Installing

On off2:

```bash
sudo ln -s /opt/openfoodfacts-infrastructure/confs/off2/systemd/system/email-failures@.service /etc/systemd/system/
sudo ln -s /opt/openfoodfacts-infrastructure/confs/off2/systemd/system/sanoid_check.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable sanoid_check.timer
```

Test the check:
```bash
# check not already running
sudo systemctl status sanoid_check.service
sudo systemctl start sanoid_check.service
sudo systemctl status sanoid_check.service
```

It worked !

Same operation on ovh3 (but with ovh3 folder).

## OnFailure for sanoid and syncoid

While installing sanoid check, I realized `email-failures@.service` did not exists already,
and that sanoid and syncoid did not email their failures !

So I override sanoid.service and modify syncoid.service to add it.

After adding relevant files to git,

On off2:
```bash
sudo ln -s /opt/openfoodfacts-infrastructure/confs/off2/systemd/sanoid.service.d/override.conf /etc/systemd/system/
sudo systemctl daemon-reload
```

same on ovh3 (but with ovh3 folder).