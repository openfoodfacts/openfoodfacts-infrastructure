# How to resync ZFS replication

It happens that some time, syncoid fails for too long to replicate a dataset,
and it become out of sync.

In this case, we normally get an error email thanks to `sanoid_check` script.

## Checking state

On the backup host and on the source host,
use `zfs list -t snap /path/to/dataset|tail` to check the status.

Search if the oldest snapshot on backup side is still available on the source host:

```bash
zfs list <dataset-name-on-backup>@<snapshot-name-on-backup-side>
```

If it's not the case, you have to search for the nearest common snapshot. It would probably be a "_daily" one or a "_monthly" one.
On the backup host, `zfs list -t snap /path/to/dataset|grep "_daily"|tail` can help you, check then availability on source side (same for `_monthly`).

When you have found the nearest common snapshot, you can resync.

## Resyncing

On the backup host, rewind to the common snapshot:
```bash
zfs rollback <dataset-name-on-backup>@<common-snapshot-name>
```

If you have an  existing vzdump snapshot `zfs list -t snap <dataset-name-on-backup>|grep @vzdump`, this is some snapshot used by Proxmox during a backup, but it might not be the same as the one on source side (it's constantly recreated), and will get in your way.
So you have to remove it on backup side, `zfs destroy <dataset-name-on-backup>@vzdump`.
See also [Dealing with vzdump snapshots](./sanoid.md#dealing-with-vzdump-snapshots)

You can then, either wait for next sync to catch up, or launch the sync manually
using syncoid (in this case, you have to craft the command by looking at syncoid-args.conf, but beware of not using --recursive option, and using the dataset name on source side and target side).

## Some other resolutions

The source dataset might have been removed (because a container / VM was removed).
In this case decide if you want to keep the data.
If not, you can destroy it.
In the other case, you have to consider moving the dataset to another location, to avoid messing with current / future datasets on the host.
