# This dockerfile builds Neovim into an tar.gz
#
# If you run docker build with the `-o <dir>` flag, it will copy the contents of
# the final stage out to that dir.
#
# The exported files are:
#
#  - nvim-linux-<arch>.tar.gz -> the archive
#
# Examine the ARG block below for --build-arg options you can pass in.

# Build on the oldest supported images, so we have broader compatibility
FROM ubuntu:18.04 AS build-stage

# these must be passed in via --build-arg
# TODO warn when not set?
ARG CC                # should be gcc-11
ARG CMAKE_EXTRA_FLAGS # See release.yml for examples
ARG CMAKE_BUILD_TYPE  # Release, Debug or RelWithDebInfo
ARG ARCH              # only used for file names

# Don't ask for TZ information and set a sane default TZ
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Upgrade to gcc-11 to prevent it from using its builtins (#14150)
# Add toolchain ppa for gcc-11 backport
# Add ca-certificates to avoid some downloads failing due to missing ca
# Set locale, may be impactful and defaults to C in ubuntu docker images
RUN apt-get update \
    && apt-get install -y software-properties-common \
    && add-apt-repository ppa:ubuntu-toolchain-r/test \
    && apt-get install -y --no-install-recommends \ 
          gcc-11 ca-certificates autoconf automake build-essential cmake \
          gettext gperf libtool-bin locales ninja-build pkg-config unzip curl \
          git \
    && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# build release
WORKDIR /neovim
COPY . .

# For now, we will enforce a clean state before building
# (these may be copied over via the above step on a user machine,
# not really in CI)
RUN rm -rf build/ .deps/

RUN CC=${CC} make CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
                  CMAKE_EXTRA_FLAGS="${CMAKE_EXTRA_FLAGS}" \
    && make DESTDIR="/neovim/build/release/nvim-linux-${ARCH}" install \
    && cd "/neovim/build/release" \
    && tar cfz nvim-linux-${ARCH}.tar.gz nvim-linux-${ARCH}

# copy artifacts out of build image
FROM scratch AS export-stage
ARG ARCH
COPY --from=build-stage /neovim/build/release/nvim-linux-${ARCH}.tar.gz /
