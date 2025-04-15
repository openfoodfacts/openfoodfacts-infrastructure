# 2024-09-05 adding ipv6 to off2

As we are moving [off-query to moji](./2024-09-04-move-off-query-to-moji.md)
we need to communicate with moji server in ipv6,
so we need to set it up in Free data center (yes it could also bring it to main web site !)

## Getting configuration

We ask for ipv6 configuration to our referent at Free, which is sponsoring the hosting of these two servers.

See page [Free Data Center](../free-datacenter.md#ipv6)

## Setting up ipv6 on off2

### IPv6 host public address

I set it up on the host through proxmox interface.

I assigned host2 host public bridge (vmbr0 in this case)
the ipv6 address 2a01:e0d:1:c:58bf:fad0::1/64 with gateway 2a01:e0d:1:c::1
I used "apply changes" button and it went well !

I verified the website was still up.

I verified ipv6 using `ping -6 2a06:c484:5::45` (osm45)

### IPv6 host private address

I assigned a private ipv6 address to the private bridge (vmbr1 in this case)

I use the [w3c ULA generator](https://tools.w3cub.com/ipv6-ula-generator), 
getting MAC using `ip link show vmbr1`.

So I assigned `fd28:7f08:b8fe:0::1/64` to vmbr1 with no gateway

Now I need forwarding between vmbr1 and vmbr0 to happen, so:

1. I put `net.ipv4.conf.all.forwarding` to 1:
  `sysctl -w net.ipv6.conf.all.forwarding=1`, also putting it in `/etc/sysctl.d/60-ip-forwarding.conf`

2. I add the iptables rule to MASQUERADING:
   `ip6tables -t nat -A POSTROUTING -s fd28:7f08:b8fe::/48 -o vmbr0 -j MASQUERADE`
   and saved it `ip6tables-save > /etc/iptables/rules.v6`


## Adding an private ipv6 address to the stunnel-client container

I assigned `fd28:7f08:b8fe:0::103/64` to the stunnel-client container with `fd28:7f08:b8fe:0::1` gateway.

Testing on stunnel-client container, by:
* first pinging the gateway: `ping -6 fd28:7f08:b8fe:0::1`
* and then pinging osm45: `ping -6 2a06:c484:5::45`



