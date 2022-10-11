# Deploying openfoodfacts-search to stagging

I'm taking note to further upgrade documentation or simply remember the steps through an example.

## Docker preparation

I added a prod.yml to make volume external (it's important to avoid the pitfall of having a docker down -v remove all data !, it also gives better control).

I made it a bit different from other project where name are absolute, because it is also dangerous, if at some point we have two different deployments on same machine… volume would be shared. I prefer to avoid a nightmare.

### Avoiding root

We want to avoid dockers running root in production.

I checked other container, one is elasticvue is in fact an nginx,
elasticsearch change user after launch, redis is ok.

Modifying the Dockerfile to create a user and pass user uid as parameter.
Also modifying the makefile to add uid

### Securing Elasticvue access

Elasticvue gives full access to the ES instance,
but we want to access it in prod because it is handy to have a quick access to ES.
We need to secure it.
As it is a vue app served by a nginx service, the best way is to have basic auth inside it.
I first tried to use the configuration by template option provided by nginx official docker image,
creating a elasticvue.conf.template and elasticvue_htppasswd.template.
but finally elasticvue image use an old nginx docker version, which do not have this template mechanism.
As it does not even have a specific entrypoint I redefined the entrypoint and use a script
that creates the htpasswd file and use sed to edit the config, this is even more flexible.


## Image creation

I first added the image creation github action. Did copy from off-server (but we got template also in openfoodfacts) and adapting it.
I had to take care that image name should be the same as the one in docker-compose.
I also had to add the TAG variable in docker-compose to set image version.

I did it on deploy-init-stagging branch (starting with deploy-* to trigger action).


## Deployment

I first added the image deployment github action. Did copy from off-server (but we got [template also in openfoodfacts](https://github.com/openfoodfacts/.github)) and adapting it.

I commented prod deployment in the triggers (v.*) because I wanted to be sure stagging would work before.

The environment name is important because it is the folder where the project will live. Better have it ending with -net or -org to mark the type of deployment (help not messing up in servers).
If it's unique among servers it's better so that we can mix deployment on same machine if we want (eg. in an emergency scenario).

Did wrote the create_external_volumes in Makefile.
I tested locally by tweaking  the env variable, and removing volumes afterwards

```bash
declare -x DOCKER_LOCAL_DATA=$(pwd)/tmp/
declare -x COMPOSE_PROJECT_NAME=po_search_prod 
declare -x COMPOSE_PATH_SEPARATOR=";"
declare -x COMPOSE_FILE="docker-compose.yml;docker/prod.yml"
make create_external_volumes
# test it works just starting setup
docker-compose up setup
sudo ls tmp/*
# clean
docker-compose rm -sf setup
docker volume rm po_search_prod_{certs,esdata01,esdata02,rediscache}
unset DOCKER_LOCAL_DATA COMPOSE_PROJECT_NAME COMPOSE_PATH_SEPARATOR COMPOSE_FILE
```

### Secrets

There are a lot secrets to set on the github repo, I had to look at all used variables.

I edited branch protection rule, because workflow are sensible:
- restrict only admins and maintainers to push to deploy-* branches
- same for main branch, with of course pull request review etc.

To create a GRAPHANA token I had to go to graphana configuration -> API keys - made an editor key and put it at repository level

### First run

I did had a very hard way making connection to server successful:

Lessons learned:
- you have to connect through ovh1 as proxy, not ovh2
- secret key is to be as in the id_rsa key, that is with the "BEGIN PRIVATE…" and "END …" lines

I had problem with the volume creation because /srv/off/docker_data was owned by root.
```bash
sudo chown off:off /srv/off/docker_data
```

## Reverse proxy setup

On OVH1, attaching to lxc 101.

Added config (copying from robotoff, removing all certbot specific stuff)

Then test and reload:

```bash
nginx -t
systemctl reload nginx
```

Also I generated the certificates:
```
certbot -d search.openfoodfacts.net
```