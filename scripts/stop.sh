#!/bin/bash

# stop and remove the borgbackup-server container

docker stop borgbackup-server
docker rm borgbackup-server
