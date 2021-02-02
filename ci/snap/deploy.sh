#!/usr/bin/env bash

set -e
set -o pipefail

SNAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBHOOK_PAYLOAD="$(cat "${SNAP_DIR}/.snapcraft_payload")"
PAYLOAD_SIG="${SECRET_SNAP_SIG}"


snap_realease_needed() {
  last_committed_tag="$(git tag -l --sort=refname|head -1)"
  last_snap_release="$(snap info nvim | awk '$1 == "latest/edge:" { print $2 }' | perl -lpe 's/v\d.\d.\d-//g')"
  git fetch -f --tags
  git checkout "${last_committed_tag}" 2> /dev/null
  last_git_release="$(git describe --first-parent 2> /dev/null | perl -lpe 's/v\d.\d.\d-//g')"

  if [[ -z "$(echo $last_snap_release | perl -ne "print if /${last_git_release}.*/")" ]]; then
    return 0
  fi
  return 1
}


trigger_snapcraft_webhook() {
  [[ -n "${PAYLOAD_SIG}" ]] || exit
  echo "Triggering new snap relase via webhook..."
  curl -X POST \
    -H "Content-Type: application/json" \
    -H "X-Hub-Signature: sha1=${PAYLOAD_SIG}" \
    --data "${WEBHOOK_PAYLOAD}" \
    https://snapcraft.io/nvim/webhook/notify
}


if $(snap_realease_needed); then
  echo "New snap release required"
  trigger_snapcraft_webhook
fi
