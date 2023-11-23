#! /bin/bash

function clean_snaps {
  POOL=$1
  D=$2
  # destroy old snapshots, keep last 100 (one full day) and the daily ones at midnight
  for S in $(zfs list -t snap $POOL/$D/products -o name -H | grep -v '0000$' | head -n -100); do echo $S; zfs destroy $S; done
  # destroy daily snapshot, keep first of each month and last 60 ones
  for S in $(zfs list -t snap $POOL/$D/products -o name -H | grep '0000$' | grep -v '01-0000$' | head -n -60); do echo $S; zfs destroy $S; done
}

clean_snaps zfs-nvme off-pro
clean_snaps zfs-nvme off
