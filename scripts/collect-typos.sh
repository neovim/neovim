#!/bin/bash

set -e

pushd "$(git rev-parse --show-toplevel)" >/dev/null 

git checkout -b catch-all-typos

while read -r pr; do
	patch -p1 <<< "$(gh pr diff "$pr")" 
done <<< "$(gh pr list --label "typo" | awk '{print $1}')"

git add -A
git commit -m "Squash all PR:s with the typo label."
git push --set-upstream origin catch-all-typos
gh pr create --fill --title "Squash of all typo pull-requests."

git checkout -

popd >/dev/null 
