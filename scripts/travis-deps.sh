#!/bin/sh

. scripts/common.sh

deps_ver=87ed1667957410341686ec50f0f8c9d2ca4abffd
deps_repo=tarruda/deps
deps_sha1=2e36cf7f01009207ec649941536f3e60740e0f7c
deps_dir=/opt/neovim-deps

github_download "$deps_repo" "$deps_ver" "$deps_dir" "$deps_sha1"
