# 2025-01-28 - Firewall work on OVH

## Changing private ipv6

The private ipv6 on ovh1 and ovh2 (vmbr0) did have a public ipv6 address which is wrong.
I changed them, to use fd28:7f08:b8fe:2::1/64 for ovh1 and fd28:7f08:b8fe:2::2/64 for ovh2.

## Firewall rules

I use the same rules as [for free](./2025-01-27-firewall-work-free.md)
but no need to expose http/https ports for ovh1,ovh2,ovh3.

I also edited the ovh proxy rules, with 22, 80, 443 and 8087 ports open (the last is stunnel).

