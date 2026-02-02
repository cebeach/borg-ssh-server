#!/bin/bash

set -euo pipefail

# Typical workflow for container build/test iteration:
# docker compose down
# docker rmi borg-ssh-server
# docker builder prune --all
# docker compose build --no-cache
# docker compose up -d
# docker logs -f borgserver

IMAGE_NAME=borg-ssh-server
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
    chmod 600 $KEYS_DIR/ssh_host_ed25519_key
    chmod 644 $KEYS_DIR/ssh_host_ed25519_key.pub
fi


# Interactive debug:
# docker run:
# -i (interactive): Keeps STDIN open even if not attached
# -t (tty): Allocates a pseudo-TTY (terminal)
# --rm: Automatically removes container when it exits (keeps system clean)
sudo docker run -it --rm \
  --name borgbackup-server \
  --hostname borgbackup-server \
  -p 127.0.0.1:2242:22 \
  -v $DATA_DIR/repos:/repos \
  -v $DATA_DIR/host_keys:/etc/ssh/host_keys \
  -v $DATA_DIR/ssh:/home/borg/.ssh \
  -v /etc/localtime:/etc/localtime:ro \
  borg-ssh-server:bookworm \
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

