#!/usr/bin/make

ENV_FILE ?= .env

# load env variables
# also takes into account envrc (direnv file)
ifneq (,$(wildcard ./${ENV_FILE}))
    -include ${ENV_FILE}
    -include .envrc
    export
endif

NAME = "label-studio"
DOCKER_COMPOSE=docker compose --env-file=${ENV_FILE}

.DEFAULT_GOAL := up
# avoid target corresponding to file names, to depends on them
.PHONY: *

#------#
# Info #
#------#
info:
	@echo "${NAME} version: ${VERSION}"

goodbye:
	@echo "🥫 Cleaning up dev environment (remove containers, remove local folder binds, prune Docker system) …"

#----------------#
# Docker Compose #
#----------------#
up:
# creates a docker network and runs docker compose
	@echo "🥫 Building and starting containers …"
ifdef service
	${DOCKER_COMPOSE} up -d ${service} 2>&1
else
	${DOCKER_COMPOSE} up -d 2>&1
endif

down:
	@echo "🥫 Bringing down containers …"
	${DOCKER_COMPOSE} down

hdown:
	@echo "🥫 Bringing down containers and associated volumes …"
	${DOCKER_COMPOSE} down -v

restart:
	@echo "🥫 Restarting containers …"
	${DOCKER_COMPOSE} restart

status:
	@echo "🥫 Getting container status …"
	${DOCKER_COMPOSE} ps

log:
	@echo "🥫 Reading logs (docker compose) …"
	${DOCKER_COMPOSE} logs -f

#------------#
# Production #
#------------#
create_external_volumes:
	@echo "🥫 Creating external volumes (production only) …"
	docker volume create ${COMPOSE_PROJECT_NAME}_app-storage
	docker volume create ${COMPOSE_PROJECT_NAME}_db-storage

#---------#
# Cleanup #
#---------#
prune:
	@echo "🥫 Pruning unused Docker artifacts (save space) …"
	docker system prune -af

prune_cache:
	@echo "🥫 Pruning Docker builder cache …"
	docker builder prune -f

clean: goodbye hdown prune prune_cache
