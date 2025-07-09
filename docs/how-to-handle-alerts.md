# How to handle alerts

This document describes for each alerts what you should do to diagnose and fix it.


## Postfix mail messages queue is high (slack)

This is fired by prometheus.

This means that Proxmox Mail Gateway defered mail queue has many messages.

This happens because of bad email addresses that can't be delivered.

- [Connect to the Proxmox Mail Gateway interface](./mail.md#administration),
- go to the *Administration* / *Queues* and check deferred mails.
  You can see them by target domains.

It might be that:
* we have emails of users with full inbox or that do not exists anymore
  In this case the best is to remove the users (remove them also in the newsletter, brevo)
* if you have emails to `root@<server>.openfoodfacts.org`,
  it might be that either the server relay is not configured correctly,
  or the `mailx` program is not installed or not the `bsd-mailx` package.
  See [mail configuration for servers](./mail.md#servers)

Finally when you are done, you can empty the queues.

*Tip*: To extract the email addresses in the detail of deferred mails,
you can use the "Console" of the developers toolbar with this expression:

```javascript
$x('//div[contains(@id, "pmgPostfixMailQueue")]//div[@class="x-grid-item-container"]//table//td[4]//text()').map(x => x.nodeValue).join("\n")
```

## sanoid_check.sh error on `<server>` (email)

This is fired by the `sanoid_check.sh` script which is regularly run by systemd
on every host using ZFS.

There are two possible alerts for each dataset.

### Last snapshot `<dataset>` is too old

This is fired because of different reasons:
* if  the dataset is a replication of a dataset on another host,
  it is not synchronized anymore.
  This might be transient because of a large volume of data to transfer,
  until syncoid catches up.

  To diagnose, go on the server and:
  * list snapshots with `zfs list  -t snapshot path/of/dataset` and check the last one
  * eventually look at syncoid logs with `journalctl -xe -u syncoid` searching for you dataset.

  Sometimes the synchronization is not working because the last snapshot has been removed on the source. See [How to resync ZFS replication](./how-to-resync-zfs-replication.md)

* if the dataset is local,
  it might be that you didn't configure sanoid (`sanoid.conf`)
  correctly for this dataset, be it you forgot to [add snapshot specification](./sanoid.md#sanoid-snapshot-configuration),
  or add it to [`no_sanoid_checks` directives](./sanoid.md#sanoid-checks).

  To diagnose, go on the server and:
  * list snapshots with `zfs list  -t snapshot path/of/dataset` and check the last one
  * eventually look at sanoid logs with `journalctl -xe -u sanoid` searching for you dataset.


### `<dataset>` has too many snapshots

This is fired because snapshots are accumulating on a dataset
(which can lead in increased disk usage).

On the server, list snapshots with `zfs list  -t snapshot path/of/dataset`.

Accumulation can be due to two main reasons:
* you forgot to configure the retention policy in `sanoid.conf` for this dataset,
  and sanoid is not removing old snapshots.
  In this case you will see a lot of hourly / daily snapshots.
* there is another source adding snapshots to this dataset, which are not removed by sanoid.
* eventually sanoid is not able to cleanup snapshots,
  use `journalctl -xe -u sanoid` to try to see why.

