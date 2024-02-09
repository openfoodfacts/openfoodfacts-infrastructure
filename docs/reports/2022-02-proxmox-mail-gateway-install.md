# Install of proxmox gateway server

**Note**: Remember this documents keeps track of installation, it might not be complete or up-to-date

See also: [the mail documentation](../mail.md)

## Proxmox Mail Gateway install

Following https://www.proxmox.com/en/proxmox-mail-gateway/get-started

VM is already there as Christian as started

I take at Install Proxmox Mail Gateway on Debian, see https://pmg.proxmox.com/pmg-docs/pmg-admin-guide.html#pmg_install_on_debian

I started with apt update && apt upgrade
* I had to re-install package manager version of config file for clamav
* I also installed vim ;-)
* I edited `/etc/locale.gen` to add `fr_FR.UTF-8` then I run `locale-gen`

Then apt install `proxmox-mailgateway`

reading `/etc/network/interfaces` show me we have a static address, this is ok

`/etc/apt/sources.list.d/pmg-enterprise.list` is ok 
[section 3.5](https://pmg.proxmox.com/pmg-docs/pmg-admin-guide.html#pmg_package_repositories).
Also gpg key is ok
I skipped the non-free section, we do not care about `rar` files.

To get graphical user interface:
`ssh -v -L 8006:10.1.0.102:8006 ovh1.openfoodfacts.org`
then https://localhost:8006/,
I had to accept risk (auto-signed certificate) to proceed.

I edit `/etc/pmg/user.conf` following [section 16.3](https://pmg.proxmox.com/pmg-docs/pmg-admin-guide.html#pmg_user_configuration_file).

first create a password hash:
```
openssl passwd  -5  -stdin -salt xxxxxx
******
```
where `xxxx` was randomly generated (using `pwgen 8`)
`****` is the password.

Then add this line to `/etc/pmg/user.conf`:
```
alex:1:0:$5$xxxxxx$xxxxxxxxxx:admin:alex@openfoodfacts.org:Alex:Garel::
```

**📝️ Note:** you need the '::' at the end contrarily of what's written in documentation (there is a column after keys)
see bug <https://bugzilla.proxmox.com/show_bug.cgi?id=3879>

**❗️Warning:** '+' is not an acceptable sign in password for it will be converted to space by http !!!

Following [section 4.5.2](https://pmg.proxmox.com/pmg-docs/pmg-admin-guide.html#_options)

Following [section 4.6.3](https://pmg.proxmox.com/pmg-docs/pmg-admin-guide.html#sysadmin_certificate_management)

Prepared:
- In [ovh web DNS](https://www.ovh.com/manager/web/#/domain/openfoodfacts.org/zone), 
  I registered `pmg.openfoodfacts.org` as a `CNAME` to `ovh1.openfoodfacts.org`
- I changed the configuration on nginx proxy (lxc 101) to redirect to pmg (so that certbot could work) :

    ```
	root@proxy:/etc/nginx/conf.d# cat pmg.openfoodfacts.org.conf
	# PMG stands for Proxmox Mail Gateway
	# We need to redirect port 80, for letsencrypt's certificate management
	server {
	
		listen 80;
		listen [::]:80;
		server_name  pmg.openfoodfacts.org;
	
		access_log  /var/log/nginx/pmg.off.log  main;
		error_log   /var/log/nginx/pmg.off_errors.log;
	
		location / {
			proxy_pass http://10.1.0.102:80$request_uri;
			proxy_set_header Host $host;
			proxy_set_header X-Real-IP $remote_addr;
			proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
			proxy_set_header X-Forwarded-Proto https;
			proxy_read_timeout 90;
			client_max_body_size 512M;
		}
	
	}
	
	root@proxy:/etc/nginx/conf.d# nginx -t
	nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
	nginx: configuration file /etc/nginx/nginx.conf test is successful
	root@proxy:/etc/nginx/conf.d# systemctl reload nginx
    ```

On the pmg machine:
```
root@mail-gateway:/home/alex# pmgconfig acme account register default tech@openfoodfacts.org
Directory endpoints:
0) Let's Encrypt V2 (https://acme-v02.api.letsencrypt.org/directory)
1) Let's Encrypt V2 Staging (https://acme-staging-v02.api.letsencrypt.org/directory)
2) Custom
Enter selection: 0

Attempting to fetch Terms of Service from 'https://acme-v02.api.letsencrypt.org/directory'..
Terms of Service: https://letsencrypt.org/documents/LE-SA-v1.2-November-15-2017.pdf
Do you agree to the above terms? [y|N]: y

Attempting to register account with 'https://acme-v02.api.letsencrypt.org/directory'..
Registering new ACME account..
Registration successful, account URL: 'https://acme-v02.api.letsencrypt.org/acme/acct/403308140'
Task OK
```


On the pmg web interface, in Certificates section, in ACME accounts / challenges I can see my account, http challenge plugin is already configured.

## Proxmox Mail Gateway configuration

In section Configuration, options tab, set Administrator Email to `tech@openfoodfacts.org`.

Following [4.7.1 Relaying](https://pmg.proxmox.com/pmg-docs/pmg-admin-guide.html#pmgconfig_mailproxy_relaying)
put default relay to `smtp-relay.gmail.com`. In our case, normally we should not relay (it's for incoming mails)

Removed any relay domains

Ports: I move public port to 24 and private port to 25, this is because we will only join PMV from trusted servers

[4.7.8 Networks](https://pmg.proxmox.com/pmg-docs/pmg-admin-guide.html#pmgconfig_mailproxy_networks):
- In networks tab I put the address of off1 and off2 without any mask.
- Same for ovh1/2/3.
- I also added usual private networks: (see <https://en.wikipedia.org/wiki/Reserved_IP_addresses>): `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`

[4.7.9 TLS](https://pmg.proxmox.com/pmg-docs/pmg-admin-guide.html#pmgconfig_mailproxy_tls)
- In TLS tab: I enables TLS

[4.7.10 DKIM](https://pmg.proxmox.com/pmg-docs/pmg-admin-guide.html#pmgconfig_mailproxy_dkim)
- I added selector with `pmg-openfoodfacts` value, key size 2048
- Then I activated DKIM and tell to sign all outgoing mail
- I clicked "View DNS record"
- In ovh I then have to use the DKIM record type and use the form to create a similar looking entry:
  checked version / Algorithm checked hash 256 / checked key type / public key (I add to join the string) / service type none / checked key valid for subdomains

- I added domain openfoodfacts.org (still in DKIM tab)

At this point I did a backup (Configuration : backup / restore)

I tested it directly on the PMG machine:
```
echo "Subject: sendmail test" | sudo sendmail -f alex@openfoodfacts.org -v alex@openfoodfacts.org
```

## iptables on ovh1

**FIXME:** I stopped postfix on ovh1 sudo systemctl stop postfix

`sudo iptables -t nat -L` shows me that masquerading is already configured:
```
	Chain POSTROUTING (policy ACCEPT)
	target     prot opt source               destination
	MASQUERADE  all  --  10.1.0.0/16          anywhere
	MASQUERADE  all  --  10.1.0.0/16          anywhere
	MASQUERADE  all  --  10.1.0.0/16          anywhere
	MASQUERADE  all  --  anywhere             anywhere
	MASQUERADE  all  --  10.1.0.0/16          anywhere
```

I configure NAT to postfix

~~`sudo iptables -t nat -A PREROUTING -p tcp  --dport 25 -j DNAT --to 10.1.0.102:25`~~

Note that, because we use nating, this means that pmg sees all incoming mails as coming from `10.1.0.1` thus avoiding PMG to filter out addresses

So finally we have to limit to certain machines directly in iptables:
```
sudo iptables -t nat -A PREROUTING -s 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 -d pmg.openfoodfacts.org -p tcp  --dport 25 -j DNAT --to 10.1.0.102:25
sudo iptables -t nat -A PREROUTING -s 213.36.253.206,213.36.253.208,146.59.148.140,51.210.154.203,1.210.32.79 -d pmg.openfoodfacts.org -p tcp  --dport 25 -j DNAT --to 10.1.0.102:25
```

**❗️Note**: important to set destination, otherwise pmg won't be able to reach external servers (because nat rule will apply to it's outgoing requests !)

To save rules (ovh1 use netfilter-persistent):
```
    cd /etc
	git status
	iptables-save -f iptables/rules.v4
	etckeeper commit "iptables rules to redirect port 25 to PMG proxmox mail gateway"
```

## configuring servers

### on dockers (aka preprod)

Configuration VM200 to send emails (this is a good candidates for tests):

`sudo apt intall postfix`
* configuration type : satellite system
* mail name: openfoodfacts.org
* relayhost: pmg.openfoodfacts.org
* mail for root: [tech@openfoodfacts.org](mailto:tech@openfoodfacts.org)
* other dest: blank
* sync: no
* local network: leave default
* use procmail: no
* default for the rest

test on preprod:
```
echo "Subject: sendmail test" | sendmail -f alex@openfoodfacts.org -v alex@openfoodfacts.org
```
### on off1

`dpkg-reconfigure exim4-config`
* mail sent by smarthost; no local mail
* mail name: openfoodfacts.org
* listen: 127.0.0.1
* other dest: off1.free.org
* visible domain name : openfoodfacts.org
* IP address smarthost:  pmg.openfoodfacts.org
* keep DNS queries minimal (dial-up): no
* local: maildir format in home
* split config : no

## on off2

Same config of exim as on off1.

But Initially I cannot send !

It's an iptables rule directly on the machine that block OUTGOING smtp requests:
```
REJECT     tcp  --  anywhere             anywhere             tcp dpt:smtp reject-with icmp-port-unreachable`
```
I removed this rule and put instead a rule to limit destination:

```
iptables -A OUTPUT -p tcp  '!' -d '146.59.148.140' --dport smtp -j REJECT --reject-with icmp-port-unreachable
```

I don't see any difference in iptables on ovh1.
I've tried to log on ovh1:
```
sudo iptables -I INPUT -s 213.36.253.208,213.36.253.206 -j LOG --log-prefix '** ALEX DEBUG **'
sudo iptables -t nat -I PREROUTING -s 213.36.253.208,213.36.253.206 -j LOG --log-prefix '** ALEX DEBUG PRE **'
```
but I don't see any incoming request !

Trying to get root mails:

I look into masquerading
and see Step 4 — Forwarding System Mail
<https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-as-a-send-only-smtp-server-on-debian-10>
<https://debian-facile.org/doc:reseau:exim4:redirection-mails-locaux>

but on debian `/etc/mailname` also does the job see <https://wiki.debian.org/Postfix> and <https://wiki.debian.org/EtcMailName>
but I'm not able to have alias work with `root: root@openfoodfacts.org`



### on ovh3

strange configuration in aliases, sending emails to admins@openfoodfacts.org !

When I unblocked the mails, I got an incredible of mails sent to root@openfoodfacts.org ! (because of a munin error, running in cron every 5 minute and sending a mail every time).
I add to suppress whole queue in PMG admin… (because it does not allow to bulk delete in queue). I received emails for more than 2 hours (fortunately gmail did some throttling)

Munin error was: `There is nothing to do here, since there are no nodes with any plugins`.
I did a `munin-node-configure --suggest --shell` without success.
Finally changing `munin.conf` to use `127.0.0.1` for `ovh3` node (instead of 10.1.0.3) fixed it !


## Testing mail quality

- in thunderbird I setup a smtp using pmg.openfoodfacts.org
- I added an ip rule to forward if source is my ip address (from home)
- i sent a mail, result: <https://www.mail-tester.com/test-kuklm574u> then <https://www.mail-tester.com/test-g6jk6pdto> (after fixing name)
