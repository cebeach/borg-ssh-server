#!/bin/bash

# Publish an image built and tagged by build.sh to Docker Hub;
#

source $(dirname $0)/config.sh

if [[ ! "$1" =~ ^[0-9]+$ ]] || (( $1 < 1000 || $1 > 60000 )); then
    echo "Error: 1000 <= borg_uid <= 60000" >&2
    exit 1
fi

borg_uid="$1"

tag=$(borg_image_tag $borg_uid)
echo "tag=${tag}"
sudo docker push ${DOCKER_ACCOUNT}/${IMAGE_NAME}:${tag}

