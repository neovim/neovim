FROM ubuntu:16.04

# This is the neovim "dev env" image, which bundles needed tools to build and run the app.
# Nvim build system uses ninja automatically, if available.

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:neovim-ppa/stable && \
    apt-get update && \
    apt-get install -y \
    build-essential \
    ninja-build \
    gettext \
    libtool libtool-bin \ 
    autoconf automake \
    cmake cmake-data \
    g++ \ 
    pkg-config \ 
    unzip curl \
    m4 \
    python-dev python-pip python3-dev python3-pip \
    && apt-get clean

RUN mkdir -p /src/github.com/neovim 
WORKDIR  /src/github.com/neovim 

CMD /bin/bash
