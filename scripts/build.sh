#!/bin/bash

# Build a borg-ssh-server image and tag it according to the metadata in config.sh

set -euo pipefail

source $(dirname $0)/config.sh
source $(dirname $0)/show.sh

docker build \
    --build-arg BORGBACKUP_VERSION=${BORGBACKUP_VERSION} \
    --build-arg FROM=${FROM[${DEBIAN_CODENAME}]} \
    --progress=plain \
    -t ${IMAGE_NAME}:${DEBIAN_CODENAME} .

docker tag ${IMAGE_NAME}:${DEBIAN_CODENAME} ${DOCKER_ACCOUNT}/${IMAGE_NAME}:${TAG}

docker image ls

