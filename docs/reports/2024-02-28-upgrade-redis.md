# 2024-02-28 Upgrade Redis

I (Raphaël) noticed that the Redis server (v5.X) did not support some feature we were relying on (some specific XREAD syntax).
I therefore decided to upgrade it to the latest version (v7.2.4 at the time of writing).

## Upgrade of Redis

Following the [official documentation](https://redis.io/docs/install/install-redis/install-redis-on-linux/), I launched:

```bash
sudo apt install lsb-release curl gpg
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

sudo apt-get update
sudo apt-get install redis
```

I then restarted the service:

```bash
sudo systemctl restart redis
```

The command was however unresponsive, and the service was not restarted. I had to kill the process and restart the service manually.

It still did not work, and I had to reboot the VM. It didn't work either.

Checking the logs, we noticed that the configuration file (v5 syntax) was not compatible with v7.

I fetched the [sample configuration file from the new version](https://github.com/redis/redis/blob/7.2.4/redis.conf) and updated the configuration file accordingly:

- I set `protected-mode` option to `no`
- I bind to all interfaces (necessary for stunnel)
- I changed the `dir` option to `/var/lib/redis`

Restarting the service worked fine.

## Post systemd fix

It happens that redis service was continuously restarting, making the searcha-licious updater fails and restart on it's side. It was visible thanks to sentry.
We looked into this and it turns out, it was systemd not getting that the service was started. We modified the redis.conf to add `supervised systemd` (because service type is "notify", so redis must acknowledge startup through systemd socket) and also change `pidfile` directive to match the one in the service definition.
After that redis is working fine.
