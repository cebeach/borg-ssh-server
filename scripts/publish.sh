#!/bin/bash

# Publish an image built and tagged by build.sh to Docker Hub

set -euo pipefail

source $(dirname $0)/config.sh
source $(dirname $0)/show.sh

docker push ${DOCKER_ACCOUNT}/${IMAGE_NAME}:${TAG}

