#!/usr/bin/env bash

# Shows a log with changes grouped next to their merge-commit.
#
# Parameters:
#   $1    "since" commit
#   $2    "inverse match" regex pattern

set -e
set -u
set -o pipefail

__SINCE=$1
__INVMATCH=$2

is_merge_commit() {
  git rev-parse $1 >/dev/null 2>&1 \
    || { echo "ERROR: invalid commit: $1"; exit 1; }
  git log $1^2 >/dev/null 2>&1 && return 0 || return 1
}

for commit in $(git log --format='%H' --first-parent --since $__SINCE); do
  if is_merge_commit ${commit} ; then
      if [ -z "$__INVMATCH" ] || ! git log --oneline ${commit}^1..${commit}^2 \
           | grep -E "$__INVMATCH" >/dev/null 2>&1 ; then
        git log -1 --oneline ${commit}
        git log --format='    %h %s' ${commit}^1..${commit}^2
      fi
  else
    git log -1 --oneline ${commit}
  fi
done
