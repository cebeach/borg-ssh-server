#!/bin/bash

set -e

# Clean up artifacts
sudo docker compose down
sudo docker rmi -f borg-ssh-server:bookworm
sudo docker builder prune -f --all

