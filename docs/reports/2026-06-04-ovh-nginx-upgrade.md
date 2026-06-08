# 2026-06-04 OVH NGINX upgrade

On the ovh reverse proxy we were still using debian 10 (baaad),
and with the coming vulnerability,
we decided to pass to debian 12, which is possible on the proxmox host.

This is how I did it (for the record):

## Upgrade from 10 to 11

1. I edited `/etc/apt/sources.list` and every `/etc/apt/sources.list.d/*`
   and changed the code name from buster to bullseye

2. When I did `apt update`,
   it told me that the signing key from nginx repository was not known,
   so I manually added the GPG key for the nginx mainline repository[^apt_key_scope]:
   ```bash
   curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/nginx-archive-keyring.gpg >/dev/null
   ```

3. I updated the system step by step:

    * `apt update`
    * `apt upgrade --without-new-pkgs`
    * `apt full-upgrade`

4. During the installation process several questions arose:
   * changes in `/etc/nginx/nginx.conf`: I kept my file,
     but afterward, I changed `user www-data;` to `user nginx;`[^user_nginx_is_from_repo].

     This also means I had to do some chown[^chown_afterward]:
     ```bash
     sudo chown nginx -R /var/cache/nginx /var/www
     ```

   * changes in `/etc/sudoers`: get maintainer file,
     but afterward, restore the %sudo line with `%sudo ALL=(ALL) NOPASSWD: ALL`

5. I rebooted; the `anubis` service was not working,
   complaining about being unable to access `/run/systemd/unit-root/run/anubis/wiki`,
   this was because the container didn't have the right options for new systemd,
   (as explained in [proxmox, systemd needs nesting capability](../proxmox.md#systemd-needs-nesting-capability)),
   so, on the host (ovh1), I edited `/etc/pve/lxc/101.conf` to add:
   ```
   feature: nested=1
   lxc.cap.drop: "sys_rawio audit_read"
   ```
   and restarted the container.

After that it was running fine.

Verifying it works: `systemctl list-units --state failed`

I then redid the process to upgrade from debian 11 to debian 12.

At upgrade time, the only question was about crontab file, and I kept the maintainer one.


[^chown_afterward]: really I did the chown afterward,
  because I forgot to check it (I thought the installation would take care of it).
  The symptom was images on the wiki downloading only partially,
  (because the cache was not readable by user nginx)

[^user_nginx_is_from_repo]: I discovered afterward that this difference of user
  comes from the nginx repository (as opposed to debian one).
  Another difference is that it does not include the `sites-enabled` directory.

[^apt_key_scope]: Putting a key in `/etc/apt/trusted.gpg.d/` trusts it for all APT sources.
  A tighter approach is to store it in `/usr/share/keyrings/` and use `signed-by=...`
  on the nginx repository entry.

## Hetzner and Scaleway proxy to mainline NGINX

Because of the current [HTTP/2 vulnerability](https://blog.calif.io/p/codex-discovered-a-hidden-http2-bomb) I also moved Hetzner and Scaleway to the NGINX mainline repository.

For this I used Ansible. See [PR #641](https://github.com/openfoodfacts/openfoodfacts-infrastructure/pull/641)
