#!/usr/bin/env bash

# Prints a nicely-formatted commit history.
#   - Commits are grouped below their merge-commit.
#   - Issue numbers are moved next to the commit-id.
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

# Removes parens from issue/ticket/PR numbers.
#
# Example:
#   in:   3340e08becbf foo (#9423)
#   out:  3340e08becbf foo #9423
_deparen() {
  sed 's/(\(\#[0-9]\{3,\}\))/\1/g'
}

# Cleans up issue/ticket/PR numbers in the commit descriptions.
#
# Example:
#   in:   3340e08becbf foo (#9423)
#   out:  3340e08becbf #9423 foo
_format_ticketnums() {
  nvim -Es +'g/\v(#[0-9]{3,})/norm! ngEldE0ep' +'%p' | _deparen
}

for commit in $(git log --format='%H' --first-parent "$__SINCE"..HEAD); do
  if is_merge_commit ${commit} ; then
      if [ -z "$__INVMATCH" ] || ! git log --oneline ${commit}^1..${commit}^2 \
           | >/dev/null 2>&1 grep -E "$__INVMATCH" ; then
        git log -1 --oneline ${commit}
        git log --format='    %h %s' ${commit}^1..${commit}^2
      fi
  else
    git log -1 --oneline ${commit}
  fi
done | _format_ticketnums
