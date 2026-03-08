#!/bin/bash

# Start up the borg-ssh-server container using docker compose;
# assumes the following directory structure:
# data/ssh/ssh_host_ed25519_key         ... created if not existing
# data/ssh/ssh_host_ed25519_key.pub     ... created if not existing
# data/ssh/authorized_keys              ... required; see config/authorized_keys_template
# data/repos                            ... created if not existing
# scripts/start.sh (this file)
# config/authorized_keys_template

set -euo pipefail

source $(dirname $0)/config.sh
source $(dirname $0)/show.sh

ROOT=$(dirname $0)/..

cd $ROOT

# Ensure directories exist
for dir in repos ssh; do
    mkdir -p "$ROOT/data/$dir"
done

# Build host key if it doesn't already exist
if [[ ! -f $ROOT/data/ssh/ssh_host_ed25519_key ]]; then
    ssh-keygen -t ed25519 -f $ROOT/data/ssh/ssh_host_ed25519_key -N ""
else
    echo "-*- $ROOT/data/ssh/ssh_host_ed25519_key"
fi

# Enforce key permissions
chmod 600 $ROOT/data/ssh/ssh_host_ed25519_key
chmod 644 $ROOT/data/ssh/ssh_host_ed25519_key.pub

# Give a heads-up if the authorized_keys file doesn't exist
if [[ ! -f $ROOT/data/ssh/authorized_keys ]]; then
    echo "-E- Please create $ROOT/data/ssh/authorized_keys"
    echo "-E- Template: $ROOT/config/authorized_keys_template"
    exit 1
else
    echo "-*- $ROOT/data/ssh/authorized_keys"
fi

# Start the container
IMAGE=${DOCKER_ACCOUNT}/${IMAGE_NAME}:${TAG} docker compose -f compose/compose.common.yml -f compose/compose.dev.yml up -d

# Show docker ps
echo
echo '$ docker ps -a --filter name=borgbackup-server'
docker ps -a --filter name=borgbackup-server

echo
echo '$ docker port borgbackup-server'
docker port borgbackup-server

echo
echo '$ docker logs --tail 100 -f borgbackup-server'
docker logs --tail 100 -f borgbackup-server

