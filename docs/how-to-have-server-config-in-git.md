# How to have server config in git

We use git to store and track servers / containers or VM specific configurations.
See [Explanation on server configuration with git](./explain-server-config-in-git.md)

## Setup the repository

Normally we use root and we clone this repository in `/opt/openfoodfacts-infrastructure`

To be able to clone the repository you will need to [use a deploy key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#deploy-keys).

If available you can use the `root` ssh public key.

[Create one if necessary](#create-a-ssh-key), copy the public key content (eg. `/root/.ssh/id_ed25519.pub`)
and add it as a [deploy key to this repository](https://github.com/openfoodfacts/openfoodfacts-infrastructure/settings/keys)

You can then use a normal git clone command: `cd /opt; git clone git@github.com:openfoodfacts/openfoodfacts-infrastructure.git`

### Create a ssh key

If root has yet no key you can create a new one, with:
```bash
ssh-keygen -t ed25519 -C "root@some-descriptive-host-name"
```

### Using multiple repository

Strangely enough, Github only allows to access one repository per public key.
If you need to clone more than one repository with the same user,
you will need to create new ssh key, use a specific server-name to create the project and use a specific configuration to connect to the git server.

Here I will use root-my-project for example

Create a ssh key:
```bash
ssh-keygen -t ed25519 -C "root@my-project-my-server-name" -f "/root/.ssh/github_my-project"
# cat the pub key
cat /root/.ssh/github_my-project.pub
```

You can then add this key to the deploy keys of your projects.

But then, edit ssh config (eg `/root/.ssh/config`) to add an alias to github server for your project and specify the key we just created as authentication:

```conf
Host github.com-my-project
    Hostname github.com
	IdentityFile=/home/off/.ssh/github_my-project
```

Then clone your project using this server alias name:

```bash
git clone git@github.com-my-project:my-org/my-project.git`
```

For more information [github documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#using-multiple-repositories-on-one-server)


## Use repository to store server configurations

See [Explanation on server configuration with git](./explain-server-config-in-git.md)

You simply create a folder for your service in `confs/` directory.

Create a structure that loosely mimic the one in `/etc` for the files you have to modify. Them symlink `/etc` files to your repository files.

**IMPORTANT:** never ever put files with passwords in the git repository ! See [Files with passwords](#files-with-passwords)

**NOTE:** `/etc/pve` on proxmox hosts is a specific fuse mount that just expose proxmox configuration as if they where files. You won't be able to use symlinks for this part.

**BEWARE:** logrotate needs file to be owned by root, or it will fail silently.

### Files with passwords

Try to isolate private file with as minimal content as possible (most services configuration enables that, either through include or specific directives).

If you have private files that you can't put in the repository, you have two situations:

* if the file is easy to re-create (eg. a letsencrypt certificate, or an API key, or a password than can be reset easily) just leave it to the server only
* if it's not easy to re-create, put it in the shared KeepassX


## Use repository to store server scripts

Server specific scripts can also be pushed to this repository to have a backup and follow evolution.