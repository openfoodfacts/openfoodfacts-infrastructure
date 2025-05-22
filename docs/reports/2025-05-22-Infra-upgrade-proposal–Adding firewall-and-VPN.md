# 2025-05-22 - Infra upgrade proposal – Adding firewall & VPN

## Introduction

I have been asked to pitch a solution to connect all the data centers between them via a VPN connection. I also made some changes related to security.

To summarize, this document proposes to:

- **Replace** iptable with software firewall (like OPNsense)
- **Add** a site-to-site VPN between data centers

To recap, currently, the infra looks like this:

<figure align="center">
    <a href="media/network_diagram.svg">
        <img alt="Current network diagram" title="Current network diagram" src="media/network_diagram.svg">
    </a>
	<figcaption>Current network diagram</figcaption>
</figure>

As you can see, the security and routing of the subnets are managed by the reverse proxy/iptables, and the different data centers are connected between them via the Internet.

This document and the proposed improvements are as follows:

- **Security:** stateful filtering, complete and centralized logging, trafic inspection
- **Simplified administration:** Modern web interface, centralized rules and user management
- **Audit and compliance:** Improved traceability of access and changes
- **Securized connexion between sites:** Crypted, automated and resilient VPN tunnels

## 1 - Remplacing Iptables with OPNSense

Iptables is a great tool, but more feature-rich solutions exist, such as software firewalls like OPNsense.

> *Iptables is technicaly a software firewall but really basic.*

### Why replace Iptables with OPNSense

Here is a table of the differences between IPtable and OPNSense:

<center>

| **Criterion**                | **Iptables**                       | **OPNSense**                                  |
|----------------------------- |------------------------------------|-----------------------------------------------|
| **Management Interface**     | Command-line only                  | Intuitive web interface                       |
| **Users management**         | Manual, hard to manage             | Easy, vie the web interface
| **Rule Visibility**          | Complex, hard to read              | Clear, well-documented rules                  |
| **Logging**                  | Limited, not centralized           | Rich, filterable, exportable logs             |
| **Multi-site Administration**| Manual, not centralized            | Standardization via reproducible templates    |
| **Advanced Features**        | Not integrated                     | Includes IDS/IPS, proxy, VLAN, VPN            |
| **Maintenance / Scalability**| Scripted, low scalability          | Modular system, easy and regular updates      |

**Table of differences between Iptable and OPNSense**

</center>

It complies with the goal of simplifying administration, reducing human error, and improving security.

### Why use OPNSense

Others software firewall exists (like Untangle or Ipfire) but it's, for me, the most secured, maintained and serious project. Opinion i will be happy to discuss of course !

Based on pfSense, it is a fork that was created when the company behind it began to close-source some parts of pfSense.

It come with many benefits:
- **Modern interface:** intuitive, browser-accessible, with role management.
- **Based on hardened FreeBSD:** stability, security, high network performance, frequen security updates.
- **Integrated features:** VPN, IDS/IPS (Suricata), proxy, DNS, DHCP, HA, etc.
- **Modularity:** plugins can be activated as needed.
- **Active community:** comprehensive documentation, forums, frequent updates.
- **Open source solution:** free, no license fees, auditable code.

## 2 - Adding VPN site-to-site connexion between the data centers

As I mentioned at the beginning of this document, I was asked to consider a solution to securely connect all the data centers using VPN. To achieve this, I propose using the OPNsense firewall to connect them.

Briefly, this is what using VPNs with OPNSense will do:
- Creating crypted tunnels between data centers
- Routing every site's subnets between them
- Persistent conexions, mouting at boot
- Managing these tunnels via the same interface

**Problem:** The big problem i see here is that each data centers need to have differents subnet IP's range.

For exemple:
- Free: 10.0.2.0/24
- Hetzner: 10.0.3.0/24
- ...

### Why using Wireguard ?

WireGuard is a modern, peer-to-peer, VPN protocol that offers several advantages over IPsec:

- **Simplicity:** WireGuard has a much smaller codebase (~4,000 lines vs. hundreds of thousands for IPsec), making it easier to audit and maintain.
- **Performance:** It uses state-of-the-art cryptography and is highly optimized, often resulting in lower latency and faster throughput.
- **Ease of configuration:** Peer-to-peer model with simple configs — no complex negotiation or phase settings like in IPsec.
- **Better for NAT:** WireGuard works more reliably through NAT thanks to its use of UDP and keepalive mechanisms.
- **Cross-platform and lightweight:** Built directly into the Linux kernel and available on all major platforms (including OPNSense) with minimal overhead.

## 3 - Diagram of the proposed infrastructure

If everything I proposed here is done, the infra will look like this.

<figure align="center">
    <a href="media/network_diagram_VPN.svg">
        <img alt="Proposed network diagram" title="Proposed network diagram" src="media/network_diagram_VPN.svg">
    </a>
	<figcaption>Proposed network diagram</figcaption>
</figure>

Data centers will always be connected to the Internet but via VPN between them.

# Some reading
- https://docs.opnsense.org/
- https://tailscale.com/compare/ipsec
- https://www.lesnumeriques.com/vpn/wireguard-a-quoi-sert-il-tout-comprendre-sur-ce-protocole-vpn-a232535.html
- https://www.wireguard.com/
