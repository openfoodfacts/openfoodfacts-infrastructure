PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# clean up old ZFS snapshots
# last month snapshots except first day of month
for M in $(seq 1 12)
do
  for S in $(zfs list -t snap -o name | grep "@$(date -d "-$M month" +%Y%m)" | grep -v "@$(date -d "-$M month" +%Y%m)01")
  do
    echo $S
    zfs destroy $S
  done
done

# yesterday except midnight
for D in $(seq 1 30)
do
  for S in $(zfs list -t snap -o name | grep "@$(date -d "-$D days" +%Y%m%d)" | grep -v "0000$")
  do
    zfs destroy $S
  done
done

