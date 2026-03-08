#!/bin/bash

# Start the borg-ssh-server container with an interactive prompt for debug/inspection

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

# Interactive debug:
# docker run:
# -i (interactive): Keeps STDIN open even if not attached
# -t (tty): Allocates a pseudo-TTY (terminal)
# --rm: Automatically removes container when it exits (keeps system clean)
docker run -it --rm \
  --name borgbackup-server \
  --hostname borgbackup-server \
  -p 127.0.0.1:2242:22 \
  -v $ROOT/data/repos:/repos \
  -v $ROOT/data/ssh/ssh_host_ed25519_key:/etc/ssh/ssh_host_ed25519_key:ro \
  -v $ROOT/data/ssh/ssh_host_ed25519_key.pub:/etc/ssh/ssh_host_ed25519_key.pub:ro \
  -v $ROOT/data/ssh/authorized_keys:/home/borg/.ssh/authorized_keys:ro \
  -v /etc/localtime:/etc/localtime:ro \
  ${DOCKER_ACCOUNT}/${IMAGE_NAME}:${TAG} \
  /bin/bash

# Stuff we can do interactively in the container to check it:

# Here we can see /bin/bash runs as pid 1:
# root@borgbackup-server:/# ps aux
# USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
# root           1  0.0  0.0   4196  3584 pts/0    Ss   17:37   0:00 /bin/bash
# root          15  0.0  0.0   8108  4132 pts/0    R+   17:38   0:00 ps aux

# Test SSHD configuration
# /usr/sbin/sshd -T

# Try to start SSHD manually with debug logs to standard error
# /usr/sbin/sshd -D -e
