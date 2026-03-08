#!/bin/bash

set -euo pipefail

source $(dirname $0)/config.sh
source $(dirname $0)/show.sh

# Clean up artifacts
docker compose down
docker rmi -f ${DOCKER_ACCOUNT}/${IMAGE_NAME}:${TAG}
docker builder prune -f --all

