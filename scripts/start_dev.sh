#!/bin/bash

set -euo pipefail

# Typical workflow for container build/test iteration:
# docker compose down
# docker rmi borg-ssh-server
# docker builder prune --all
# docker compose build --no-cache
# docker compose up -d
# docker logs -f borgserver

source $(dirname $0)/config.sh
source $(dirname $0)/show.sh

if [[ ! "$1" =~ ^[0-9]+$ ]] || (( $1 < 1000 || $1 > 60000 )); then
    echo "Error: 1000 <= borg_uid <= 60000" >&2
    exit 1
fi

borg_uid="$1"

BUILD_DIR=~/docker/$IMAGE_NAME
DATA_DIR=$BUILD_DIR/data
KEYS_DIR=$DATA_DIR/host_keys

cd $BUILD_DIR

# Ensure data dirs exist
for dir in repos host_keys ssh; do
    mkdir -p "$DATA_DIR/$dir"
done

# Build host key if it doesn't already exist
if [[ ! -f $KEYS_DIR/ssh_host_ed25519_key ]]; then
    ssh-keygen -t ed25519 -f $KEYS_DIR/ssh_host_ed25519_key -N ""
else
    echo "-*- $KEYS_DIR/ssh_host_ed25519_key"
fi

# Enforce key permissions
chmod 600 $KEYS_DIR/ssh_host_ed25519_key
chmod 644 $KEYS_DIR/ssh_host_ed25519_key.pub

# Give a heads-up if the authorized_keys file doesn't exist
if [[ ! -f $DATA_DIR/ssh/authorized_keys ]]; then
    echo "-E- Please create $DATA_DIR/ssh/authorized_keys"
    echo "-E- Template: $BUILD_DIR/config/authorized_keys_template"
    exit 1
else
    echo "-*- $DATA_DIR/ssh/authorized_keys"
fi

image=${DOCKER_ACCOUNT}/${IMAGE_NAME}:$(borg_image_tag $borg_uid)
echo "image=${image}"

# Start the container
sudo IMAGE=${image} docker compose -f compose/compose.common.yml -f compose/compose.dev.yml up -d

# Show docker ps
echo
echo '$ docker ps -a --filter name=borgbackup-server'
sudo docker ps -a --filter name=borgbackup-server

echo
echo '$ docker port borgbackup-server'
sudo docker port borgbackup-server

echo
echo '$ docker logs --tail 100 -f borgbackup-server'
sudo docker logs --tail 100 -f borgbackup-server

