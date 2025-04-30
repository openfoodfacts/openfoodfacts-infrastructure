# Explanation on server configuration with git

For more and more services and servers, we use git to store the configuration files that are different from basic configuration.

The idea is to be able to follow server configuration evolution without (for now) using tools like ansible or similar tools (which may require more work and are not always as declarative as they pretend)[^pyinfra].

[^pyinfra]: By the way I would rather use [pyinfra](https://docs.pyinfra.com/en/2.x/) which is faster and far more flexible

## Implementation

### Ansible role

The `git_based_config` role in ansible folder
is used to install the repository on the server.
It provides additional tasks to update it.

### For servers and most services

On every servers we have a `/opt/openfoodfacts-infrastructure` repository which is a clone of this projects by `root`.

To be able to commit changes we add the root public key in deploy keys of the github repository, with write access.
See [How to have server config in git](./how-to-have-server-config-in-git.md).

For each server, or container or VM, we have a folder in `/opt/openfoodfacts-infrastructure/confs`.

Then as much as we can, we link the configuration files from the `/opt/openfoodfacts-infrastructure/confs` folder to the corresponding `/etc` folder of the server.

We only commit files that differ from main distribution.

We also try to commit minimal file, using includes and .d directories as much as possible.

For example we use override definitions for existing systemd units ([use `systemctl edit`](https://www.freedesktop.org/software/systemd/man/latest/systemctl.html#edit%20UNIT%E2%80%A6))

### For services with their own repository

For services with their own repository we might prefer to store corresponding files in the repository itself.

This is the case for Product Opener (aka openfoodfacts-server), where we use the [conf directory](https://github.com/openfoodfacts/openfoodfacts-server/tree/main/conf)

## Best practice

Try not to forget any specific configurations !

You are always encouraged to add comments in the configuration files to explain specific settings.

See also: [How to have server config in git](./how-to-have-server-config-in-git.md)

### Commiting your changes from a server

While it's better to do a pull request for documentation and other things,
it's perfectly ok to commit a configuration change or script change directly from the server on develop branch [^commit_develop].

The best way to commit is:
1. ensure you put right authorship, setting GIT_AUTHOR_NAME and GIT_AUTHOR_EMAIL [^git_author]
2. commit your changes with a meaningful message (eventually more than one commit)
3. use `git pull --rebase --autostash` to fetch remote updates, while keeping your working changes (autostash)
4. use `git push` to push your changes to the remote


[^commit_develop]: it's even the best choice on production servers 
to avoid having part of the configurations failing out of sync because you are on a specific branch,
or taking the rist of messing things up, just for small changes.

[^git_author]: don't hesitate to add a script in utils folder to do that.

## Limitations

* there is no guarantee every needed configuration file are linked and monitored in git
* some (rare) services do not accept symlinks
* proxmox `/etc/pve` files are in fact a fuse mount of pve server configurations and not real files and can't be symlinked
* you must **take attention not to push files which contains secrets !**
