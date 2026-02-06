#!/bin/bash

# stop the borgbackup-server container

sudo docker stop borgbackup-server
sudo docker rm borgbackup-server

