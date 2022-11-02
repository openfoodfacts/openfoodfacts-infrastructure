# Docker at Open Food Facts


## Technology stack

See also:  [Continous Integration and Continuous Delivery](cicd.md#technology-stack)

### Docker (*idempotency*)

The process of dockerizing applications is an important step towards achieving a modern-day great Continuous Integration and Continous Delivery process.

**Dockerization** avoids common pitfalls in deployment processes, such as having to write idempotent deployment scripts to deploy an application. A Docker container build can be run many times producing each time the same resulting image.

Most of Open Food Facts git repositories have a `Dockerfile` that is used both to test changes locally, but also to ease automated testing and automated deployments through **idempotency** (a.k.a repeatabilty, or the ability to re-run a deployment X times without problems).


### Docker-Compose (*orchestration*)

We use `docker-compose` to deploy our applications to our servers: it is a simple **orchestator** that can deploy to a single machine at once.


An alternative like `docker swarm` or `kubernetes` could be considered in the future to deploy to multiple machines at scale, but it currently does not make much sense considering the small amount of servers used to run Open Food Facts.

### Env file (*secret management*)

Every OFF repo has a `.env` file that contains the secrets needed by the application to run properly. The `.env` file is loaded by the `docker-compose` commands.

The default `.env` file in the repo is ready for local development and should rarely be modified.

In pre-production and production, the `.env` file is populated by the GitHub action (using GitHub environment secrets) before deploying to the target environment.

**Warnings:**
* The default `.env` file should rarely change. If you need a different environment locally, create a new env file (e.g `.env.test`) and set `ENV_FILE=.env.test` before running the `Makefile` commands. 
* Do not commit your env files to the repos !
* you may use `direnv` to override some variables on a folder basis. See [how-to for openfoodfacts-server](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/how-to-guides/use-direnv.md)


## Best Practice for Docker containers

Here are some important rules. The document also explain why we follow those rules.
From time to time you might have good reason to bend or break the rules, 
but only do it if needed.
Rules also enables having a consistent experiences between projects.


### Images

* If possible use an official image. If you use another image take a look on how it's built.
  It's important to be future proof and to be able to rely on a good base.

* We try to favor images based on debian, if really needed you can use arch or other architecture.
  This is to keep consistent and manageable to admin and developers to debug images.

### Enable configuration through environment

We really want to be able to run the same project multiple time on same machine / server.
For that we need to ensure that we can configure the docker-compose project.

You have two mechanism to configure the docker-compose:
- docker-compose file composition, use it for structural changes
- .env is the prefered way to change configuration (but can't solve it all)


* Avoid too generic name for services. Like `postgresql` it's better to use `myproject_db`.
* Every public network should have a configurable name.
  To be able to run the project more than once, to also be able to connect docker-compose between them.
* Every port exposure should be changeable through env.
  We want to be able to change port (run multiple time same project),
  and to keep exposure to localhost on dev (avoid exposure on public wifi).
* Never use *container_name* (let docker-compose build the name)
* Never user static names for volumes, let docker-compose add a prefix
* try to stitch to the default network
  and setup a network with a configurable name for exchanges with other projects services
  (that is located in other docker-compose).
* restart directive should always be configurable.
  While we want auto-start in production, we don't want it on dev machines.
* always prefer prod defaults for variable, or safe default.
  For example it's better to only expose to localhost.
  And if a variable is missing in prod it should never create a disaster.


### Dev config

The docker-compose.yml should be as close as possible to production.

Put specific configurations in a docker/dev.yml

* The build part should only be in dev docker-compose.
  (see why we use images only in prod)
* use a USER_UID / USER_GID parameter to align docker user with host user uid.
  This avoid having problems with file permissions.
* bind mount code so that it's easy to develop.
* make it possible to connect the project between them on dev, as if it was on production.
  This enables manual integration testing of all the project all together.

### Prod config

Here I talk about production, but staging is as much possible identical to prod.

* There should be no build in production, containers should be defined by their images.
  We want to be able to redeploy easily only depending on the container registry, not external packages repositories and so on.


* every volume containing production data should be external (to avoid a `docker-compose down` fatality if `-v` is added). The Makefile should contain a creation target (`create_external_volumes`)
* shared network name should have a prefix which reflect the environment: like stagging / prod
* COMPOSE_PROJECT_NAME should use <project_name>_: like po_stagging, po_prod, ...

see also https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/146

### Security

* Try hard not to use root in docker images. (it's ok if root is only used to launch a service that immediately drops privileges)
  * for containers that contains code, or elements that are edited by developers and bind mounted at dev time
* expose to localhost only whenever possible. Only expose to all interfaces when needed
* be aware that docker use an alternative table for ip tables.
  A blocking INPUT or OUTPUT rule won't apply to docker exposed port.
  You can instead add rules to DOCKER-USER chain.
