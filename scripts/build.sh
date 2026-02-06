#!/bin/bash

# Build a borg-ssh-server image and tag it according to the metadata in config.sh

set -euo pipefail

source $(dirname $0)/config.sh
source $(dirname $0)/show.sh

sudo docker build \
    --build-arg BORGBACKUP_VERSION=${BORGBACKUP_VERSION} \
    --build-arg DEBIAN_CODENAME=${DEBIAN_CODENAME} \
    -t ${IMAGE_NAME}:${DEBIAN_CODENAME} .

sudo docker tag ${IMAGE_NAME}:${DEBIAN_CODENAME} ${DOCKER_ACCOUNT}/${IMAGE_NAME}:${TAG}

sudo docker image ls

