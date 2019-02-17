#!/usr/bin/env bash

set -e

brea update || brew update
brew install vim --with-override-system-vim
