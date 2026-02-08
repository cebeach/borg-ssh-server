#!/bin/bash

# metadata required to build and publish the borg ssh server image

# borgbackup pip package version spec; see https://pypi.org/project/borgbackup/
BORGBACKUP_VERSION=1.4.3

# debian release codename; see https://www.debian.org/releases/
DEBIAN_CODENAME=bookworm

# Docker account name used for Docker Hub upload
DOCKER_ACCOUNT=chadly314

# base name assigned to the image
IMAGE_NAME=borg-ssh-server

# docker container integer revision used in tag
IMAGE_REVISION=5

TAG=${BORGBACKUP_VERSION}-${DEBIAN_CODENAME}-r${IMAGE_REVISION}

