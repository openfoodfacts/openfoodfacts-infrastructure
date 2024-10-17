# Linux server

Here are some guidelines for linux servers.

**FIXME:** this doc is not up-to-date and must be reviewed.

Note that we have some servers (which are bare metal installs.
While others are [proxmox hosts](./proxmox.md).
On proxmox some VM are lxc containers, while other are QEMU VM.

Every server is referenced in 
[CT and VM list of OFF infrastructure](https://docs.google.com/document/d/14x5yPdcJ8uLoc5zb0HYjb_EYUIWZzOlaPWYyLSuIcTw/edit?resourcekey=0-h0h9ksbTUBykEDuBkXH4fg#)

## Etckeeper

We use `etckeeper` with `git` backend on as much server as possible.

See https://etckeeper.branchable.com/README/

So whenever you make a change to `/etc`.
When possible before making your change, 
as root, do a `git status` and then `etckeeper commit "save before changes"`.
And after, do a `etckeeper commit "<a descriptive message>"` afterwards.

## Email

We use either postfix or exim as a satellite of a smart_host.

Every outgoing mail must pass through the proxmox mail gateway,
which is registered in spf record and adds DKIM signature.

For configuration, see [mail - Servers](./mail.md#servers)

## Iptables

We use iptables on a lot of servers (generally host servers).

We use iptables-persistent to save rules, and restore them at startup.

On ovh servers, rules are in `/etc/iptables/rule.v{4,6}`
On off1, rules are in `/etc/iptables.up.rules`

Remember, that docker as it's own chains that are not affected by `INPUT` and `OUTPUT` rules.
So it won't block a port exposed by docker. Use `DOCKER-USER` chain for that.
see https://docs.docker.com/network/iptables/

## Root .bashrc

Most of the time root is created before auto completion package and so on are installed.
If your shell is not full featured as you are root, you might have to copy `/etc/skel/.bashrc` to `/root`

## No color in shell

Check your TERM variable: `echo $TERM`, it should be `xterm-256color` or `linux`

Check .bashrc is the right one `diff $HOME/.bashrc /etc/skel/.bashrc`
if not copy the one from `/etc/skel/.bashrc`

## No autocompletion for commands

Check `bash-completion` is installed: `dpkg --verify bash-completion && echo ok`

Check .bashrc is the right one `diff $HOME/.bashrc /etc/skel/.bashrc`
if not copy the one from `/etc/skel/.bashrc`
