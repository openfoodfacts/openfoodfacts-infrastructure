# 2026-09-25 OVH2 107 (matomo) Upgrades

Several maintenance updates of Matomo and it's OS were done.

## Matomo upgrade from 5.1.1 to 5.14.0

Before updating Matomo, I took a snapshot of the LXC container in Promox. Afterwards,
I first upgraded the plugins from the Matomo admin UI. Then, Matomo warned that the DB
needed upgrading, so I ran `/var/www/html/matomo/console core:update` in the shell.
As the `QueuedTracking` was updated, I also applied the fixes [mentioned here](../explanation/services/matomo.md).

Following that, the Matomo upgrade was done - also from the Matomo UI. I had
to run `console core:update` multiple times until the UI actually loaded without any
warnings. That did solve everything, though, and tracking seems to work as expected.