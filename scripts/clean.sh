#!/bin/bash

set -euo pipefail

source $(dirname $0)/config.sh
source $(dirname $0)/show.sh

# Clean up artifacts
sudo docker compose down
sudo docker rmi -f ${DOCKER_ACCOUNT}/${IMAGE_NAME}:${TAG}
sudo docker builder prune -f --all

