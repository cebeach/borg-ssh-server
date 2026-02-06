#!/bin/bash

# borgbackup pip package version spec
# https://pypi.org/project/borgbackup/
BORGBACKUP_VERSION=1.4.3

# debian release codename
# https://www.debian.org/releases/
DEBIAN_CODENAME=bookworm

# Docker account name used for Docker Hub upload
DOCKER_ACCOUNT=chadly314

# base name assigned to the image
IMAGE_NAME=borg-ssh-server

# docker container integer revision used in tag
IMAGE_REVISION=2

borg_image_tag() {
    local borg_uid="$1"
    printf '%s-%s-uid%s-r%s\n' \
        "$BORGBACKUP_VERSION" \
        "$DEBIAN_CODENAME" \
        "$borg_uid" \
        "$IMAGE_REVISION"
}

