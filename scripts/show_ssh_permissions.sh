#!/bin/bash

# Connect to a running borgbackup-server container and inspect ssh permissions

sudo docker exec -it borgbackup-server bash -lc '
set -e
ls -ld /home/borg /home/borg/.ssh /home/borg/.ssh/authorized_keys
stat -c "%A %u:%g %n" /home/borg /home/borg/.ssh /home/borg/.ssh/authorized_keys
'
