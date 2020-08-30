#!/usr/bin/env bash

set -e
set -o pipefail

sudo apt update
sudo usermod -aG lxd $USER
sudo /snap/bin/lxd.migrate -yes
sudo /snap/bin/lxd waitready
sudo /snap/bin/lxd init --auto

