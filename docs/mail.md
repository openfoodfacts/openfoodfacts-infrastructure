# Mail on Open Food Facts infrastructure

Because mail is difficult to setup, we use [Proxmox Mail Gateway](https://www.proxmox.com/en/proxmox-mail-gateway) as a relay to all servers. It ensure correct SPF, but also it adds DKIM signature.

The DKIM and spf records are configured on main domain *openfoodfacts.org*.

While DKIM is specific (because Brevo and Google keys are distinct by construction), 
main SPF rule includes brevo and google servers.

No server receive mail, but they should be able to send them.

<a id="only-domain"></a>

**📝Note:** We ONLY support emails address on primary domain (`openfoodfacts.org`) and we DO NOT support emails on sub domains (aka `xxx.openfoodfacts.org`).


## Google Workspace

We use Gmail for email boxes and groups.

We have a DKIM record configured for google domain and sub-domains in the DNS, we also take into account in SPF rule.
You can find the public key in google workspace admin console, under gmail.


## Brevo

We use Brevo to send newsletters.

We have a DKIM record configured for the Brevo domain in the DNS, we also take into account in SPF rule.
They use the **hello.openfoodfacts.org** subdomain.

You can find the public key if you are logged as admin in Brevo, in the top right corner menu, going in "Senders, domains and dedicated IPs".
Clicking on domains, and then the hello.openfoodfacts.org domain, you can see the needed DNS records. 

## Proxmox Mail Gateway

This is the `pmg`  lxc VM (aka `102`) currently on `ovh1.openfoodfacts.org`.
The install follows
[procedure starting from a debian distribution](https://pmg.proxmox.com/pmg-docs/pmg-admin-guide.html#pmg_install_on_debian).

### Administration

You can access the administration of pmg by using a tunnel on ovh1:

```
ssh  -L 8006:10.1.0.102:8006 ovh1.openfoodfacts.org -N
```
then connect to https://localhost:8006
(beware the *s* of https !)

You must have an account to connect to the service.

The most important tools you will find is Administration where you can see queues of deferred mails
or logs (on the administration entry).

See https://pmg.proxmox.com/pmg-docs/pmg-admin-guide.html#_administration

### Notable configurations options

First bare in mind that even if proxmox mail gateway is built to handle outgoing and incoming emails,
we want to use it only for outgoing emails.

We registered an letsencrypt account with tech@openfoodfacts.org

Administrator email is tech@openfoodfacts.org

Relay is set to smtp-relay.gmail.com, although we should not need it (this is for incoming mails).

SMTP private port is set to `25` and public port to `26`

In networks tab, there are all servers ips, though because of redirects,
PMG sees each incoming request as issued by `10.1.0.1`.

TLS (TLS tab) is enabled

DKIM is configured with label `pmg-openfoodfacts`, with a key size of 2048,
the public key was reported in DNS configuration

see also [installation report](./reports/2022-02-proxmox-mail-gateway-install.md)

### redirects

On DNS:
* `pmg.openfoodfacts.org` is a CNAME to `ovh1.openfoodfacts.org`
* `ovh1` ip address is reported in the spf entry of the DNS
* there is an entry for the dkim key

An iptable rule on host (`ovh1`) redirects our server incoming ips to the VM smtp port (25).
Private network address (corresponding to VM and docker ranges) are also redirected.

To add a new machine
```
sudo iptables -t nat -A PREROUTING -s 213.36.253.206,213.36.253.208,146.59.148.140,51.210.154.203,1.210.32.79 -d pmg.openfoodfacts.org -p tcp  --dport 25 -j DNAT --to 10.1.0.102:25
```
don't forget [to save iptables](./linux-server.md#iptables)

(a generic masquerading rule for VM also exists)

Note that the port 25 is in fact the private (trusted) port
(not the public one, as we are not receiving emails). This is a tweak in default config.

Also the [nginx reverse proxy](./nginx-reverse-proxy.md) (VM `101` on `ovh1`) proxies requests to `pmg.openfoodfacts.org` on port 80,
to the proxmox mail gateway VM (`102`), 
this is needed for certificate generation through letsencrypt by the gateway.


### Testing that the gateway is well configured

To do a simple test, you may use:

```bash
echo "Subject: mail gateway test" | sudo sendmail -f alex@openfoodfacts.org -v alex@openfoodfacts.org
```
directly on the `pmg` server.

To test quality of the configuration
we can send a mail to a service such as https://www.mail-tester.com/

To test using this service:
- I temporarily added an iptables rule to enable my personal ip address 
  to be forwarded to the mail gateway (as for servers)
- I added pmg.openfoodfacts.org as an smtp server in thunderbird
  and configured my personal address to use it
- I sent a mail as requested by the service
- I could then check the result
- I undo iptables and thunderbird config


## Servers

On client servers (be it a VM, a host or a standalone server),
we use either exim4 or postfix.

### Email aliases

We normally keeps a standard `/etc/aliases`.
We have specific groups to receive emails: `root@openfoodfacts.org` and `off@openfoodfacts.org`

You may add some redirections for non standard users to one of those groups.
Do not forget to run `newaliases`, and [`etckeeper`](./linux-server.md#etckeeper)
and restart the postfix service (`postfix.service` and/or `postfix@-.service`).

### Postfix configuration

Run: `dpkg-reconfigure postfix`:

* configuration type : satellite system
* mail name: openfoodfacts.org
* relayhost: pmg.openfoodfacts.org

  (with an exception for ovh1/ovh2/ovh3: 10.1.0.2)

* mail for root: tech@openfoodfacts.org
* other dest: blank
* sync: no
* local network: leave default
* use procmail: no
* default for the rest

**IMPORTANT:**
On some system, the real daemon is not `postfix.service` but `postfix@-.service`

So, for example, if you touch `/etc/alias` (with after `sudo newaliases`) you need to `systemctl reload  postfix@-.service`

### Exim4 configuration

Run: `dpkg-reconfigure exim4-config`:

* mail sent by smarthost; no local mail
* mail name: openfoodfacts.org
* listen: 127.0.0.1
* other dest: off1.free.org
* visible domain name : openfoodfacts.org
* IP address smarthost:  pmg.openfoodfacts.org
* keep DNS queries minimal (dial-up): no
* local: maildir format in home
* split config : no

### Testing

To test that mail is well configured, you can use:

```bash
echo "Subject: sendmail test xxx" | sudo sendmail -f alex@openfoodfacts.org -v root
```

or, with the `bsd-mailx` package installed [^bsd-mailx]:

```bash
echo "test message from xxx" |mailx -s "test root xxx" -r alex@openfoodfacts.org root
```

If you do not receive the email on expected group, here are some checks:

* look at logs on your server:
  * `/var/log/exim/` if you use `exim4`
  * `/var/log/mail*` if you use postfix
* look at logs on pmg VM:
  * `/var/log/mail*`
* `ping pmg.openfoodfacts.org` to verify network
* `nc -vz pmg.openfoodfacts.org 25` suceed, else you might have firewall problems:
  verify iptables on your machine and on ovh1.
  (nc command belongs to `netcat-traditional` or `netcat-openbsd` packages)
* you can even try to send a mail manualy using smtp protocol using
  `nc pmg.openfoodfacts.org` and following a tutorial about [sending email with netcat](https://www.linuxjournal.com/content/sending-email-netcat)
  If it suceed this may mean you have a problem in username to email address translation.
* `/etc/mailname` contains `openfoodfacts.org` (see also [debian wiki](https://wiki.debian.org/EtcMailName))
* check `/etc/aliases` and `/etc/email-adresses` if you use exim4


[^bsd-mailx]:
  Note that we use bsd-mailx and not the alias from mailutils as it does not behave the same.
  Noticabely it won't use /etc/mailname to complete email address which leads to problems.

### References

* [Debian reference](https://www.debian.org/doc/manuals/debian-reference/ch06.en.html#_the_mail_system)
* [Debian wiki Postfix](https://wiki.debian.org/Postfix)
* [Debian wiki Exim](https://wiki.debian.org/Exim)
