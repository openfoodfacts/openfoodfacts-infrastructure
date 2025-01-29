#!/bin/bash
# see https://sanjuroe.dev/nft-safe-reload

save_file=$(mktemp)

cleanup() {
        rm -f $save_file
}

trap "cleanup" EXIT;

RULES=/etc/nftables.conf
TIMEOUT=10

read_yesno_with_timeout() {
        read -t $TIMEOUT yn 2> /dev/null

        case "$yn" in
                y|Y)
                        return 0
                        ;;
                *)
                        return 1
                        ;;
        esac
}

save() {
        echo "flush ruleset" >> $save_file
        nft list ruleset >> $save_file
}

apply() {
        nft -f $RULES
}

restore() {
        nft -f $save_file
        echo "New configuration has been rejected and the old one restored"
}

save;

if apply; then
        echo -n "Do you want to accept the new firewall configuration? [y/n] "
        if read_yesno_with_timeout; then
                echo "New configuration has been accepted";
        else
                restore;
                exit 2;
        fi
fi

