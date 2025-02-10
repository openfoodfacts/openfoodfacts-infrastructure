# 2025-01-27 firewall on off2 reverse proxy

I found a very good introduction:
https://blog.programster.org/nftables-cheatsheet#default-nftables-config

## Testing on off1 reverse proxy


Established connections are accepted:
```bash
nft 'add rule inet filter input ct state established counter accept'
```
Loop back is ok:
```bash
nft 'add rule inet filter input iifname "lo" counter accept'
```
Local trafic is ok:
```bash
nft 'add rule inet filter input ip saddr 10.1.0.0/16 counter accept'
```

icmp is accepted:
```bash
nft 'add rule inet filter input ip protocol icmp counter accept'
```

Ports we want to accept connections on
```bash
nft 'add rule inet filter input tcp dport 22 counter accept'
nft 'add rule inet filter input tcp dport 80 counter accept'
nft 'add rule inet filter input tcp dport 443 counter accept'
```

Using drop policy:

```bash
nft add chain inet filter input '{ policy drop; }'
```

From there I can use `nft list ruleset` to see the rules.
I then build some files to configure the server.

See [commit 36b766b43a](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/36b766b43a6f63a2e35bf90088235f968cd68dff)

To test the configuration, we can use the `scripts/utils/nft-safe-reload.sh`
present in this repository.

## OFF2 reverse proxy

I only changed one file, specific to the server.

The use of `define` in the config file is a good way to make it synthetic.

See [commit 903046b5](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/903046b544cbb98948cce87e71006d73478dff93)


## Side work

I also fixed a problem with off-query certificate (in fact just an abandoned duplicate certbot configuration).
And more notably bsd-mailx was not installed on the reverse proxy.