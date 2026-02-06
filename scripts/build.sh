#!/bin/bash

# Build a borg-ssh-server image using a UID specified as the first positional command line argument.
# UID is assigned to the borg user in the container at build time; it is critical that the borg
# user's UID match the UID ownership of the bind mount for /home/borg/.ssh/authorized_keys to
# prevent ssh from rejecting the mounted /home/borg/.ssh/authorized_keys.

source $(dirname $0)/config.sh
source $(dirname $0)/show.sh

if [[ ! "$1" =~ ^[0-9]+$ ]] || (( $1 < 1000 || $1 > 60000 )); then
    echo "Error: 1000 <= borg_uid <= 60000" >&2
    exit 1
fi

borg_uid="$1"

sudo docker build \
    --build-arg BORGBACKUP_VERSION=${BORGBACKUP_VERSION} \
    --build-arg DEBIAN_CODENAME=${DEBIAN_CODENAME} \
    --build-arg BORG_UID=${borg_uid} \
    -t ${IMAGE_NAME}:${DEBIAN_CODENAME} .

# TO-DO: verify image built without errors

tag=$(borg_image_tag $borg_uid)
echo "tag=${tag}"
sudo docker tag ${IMAGE_NAME}:${DEBIAN_CODENAME} ${DOCKER_ACCOUNT}/${IMAGE_NAME}:${tag}

sudo docker image ls

