#!/usr/bin/env bash 

USAGE="This script help snapshot subvolumes (aka disks) for proxmox containers
\n
\nusage: $0 <pct-num> <pct-num> …
\n"

set -e
if [[ -z "${@}" ]]
then    
    >&2 echo -e $USAGE
    >&2 echo "ERROR: Give pct number as argument"
    exit 1
fi  
BASE_ROOTS=($(grep "pool " /etc/pve/storage.cfg |tr -s " " " "| cut -d " " -f 2))
if [[ -z "${BASE_ROOTS[@]}" ]]
then
    >&2 echo "ERROR: Can't fined base root for pve pools"
fi

for pctnum in "${@}"
do      
    for ROOT in "${BASE_ROOTS[@]}"
    do
        # echo ROOT is $ROOT
        DATASETS=($(zfs list -o name -r $ROOT|grep subvol-$pctnum-disk- 2>/dev/null|| true))
        for dataset in "${DATASETS[@]}"
        do
            TIMESTAMP=$(date +%Y-%m-%d--%H-%M)
            snapshot=$dataset@$TIMESTAMP
            echo creating $snapshot
            zfs snapshot $snapshot
        done
    done
done    
