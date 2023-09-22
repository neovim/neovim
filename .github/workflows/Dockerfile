FROM ubuntu:latest as builder
ARG TAG

RUN apt-get update && apt-get install -y git
RUN git clone --depth=1 https://github.com/neovim/neovim.git home/neovim
WORKDIR home/neovim
RUN git fetch origin ${TAG}:pr
RUN git switch pr

RUN apt-get update && apt-get install -y build-essential cmake curl gettext ninja-build unzip locales-all cpanminus
RUN cmake -S cmake.deps -B .deps -G Ninja && cmake --build .deps
RUN cmake --preset ci && cmake --build build
