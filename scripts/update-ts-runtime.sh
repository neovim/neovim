#!/bin/sh
#
# This script will update the treesitter runtime to the provided commit.
# Usage :
#   $0 <tree-sitter commit sha>
set -e

ts_source_dir="/tmp/tree-sitter"
ts_url="https://github.com/tree-sitter/tree-sitter.git"

base_dir="$(cd "$(dirname $(dirname $0))" && pwd)"
ts_dest_dir="$base_dir/src/tree_sitter/"
ts_current_commit="$ts_dest_dir/treesitter_commit_hash.txt"

echo "Updating treesitter runtime from $(cat "$ts_current_commit") to $1..."

if [ ! -d "$ts_source_dir" ]; then
  echo "Cloning treesitter..."
  git clone "$ts_url" "$ts_source_dir"
else
  echo "Found a non-empty $ts_source_dir directory..."
  git -C "$ts_source_dir" fetch
fi

echo "Checking out $1..."
git -C "$ts_source_dir" checkout $1

echo "Removing old files..."
find "$ts_dest_dir" -not -name "LICENSE" -not -name "README.md" -not -type d -delete

echo "Copying files..."
cp -t "$ts_dest_dir" -r "$ts_source_dir/lib/src"/*
cp -t "$ts_dest_dir" "$ts_source_dir/lib/include/tree_sitter"/*

echo "$1" > "$ts_current_commit"

make
TEST_FILE="$base_dir/test/functional/lua/treesitter_spec.lua" make test

