#!/bin/sh
#
# This script will update the treesitter runtime to the provided commit.
# Usage :
#   $0 <tree-sitter commit sha>

ts_source_dir="/tmp/tree-sitter"
ts_url="https://github.com/tree-sitter/tree-sitter.git"

base_dir="$(cd "$(dirname $(dirname $0))" && pwd)"
ts_dest_dir="$base_dir/src/tree_sitter/"

echo "$ts_dest_dir"

if [ ! -d "$ts_source_dir" ]; then
  echo "Cloning treesitter..."
  git clone "$ts_url" "$ts_source_dir"
else
  echo "Found a non-empty $ts_source_dir directory..."
fi

echo "Checking out $1..."
cd "$ts_source_dir"
git -C "$ts_source_dir" checkout $1

echo "Removing old files..."
find "$ts_dest_dir" -not -name "LICENSE" -not -type d -delete

echo "Copying files..."
cp -t "$ts_dest_dir" -r "$ts_source_dir/lib/src"/*
cp -t "$ts_dest_dir" "$ts_source_dir/lib/include/tree_sitter"/*

cd "$base_dir"
make
TEST_FILE="$base_dir/test/functional/lua/treesitter_spec.lua" make test
