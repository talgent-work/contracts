#!/usr/bin/env bash
# Usage: release-version.sh previous|next
#
# Reads the release tags (vX.Y.Z) in the history of HEAD, the pushed master
# commit.
#   previous  the highest release before HEAD, which the breaking check
#             compares against; empty before the first release.
#   next      the tag HEAD receives: the patch after the highest release in its
#             history. Empty when HEAD already carries a release, such as a
#             minor tagged by hand, or when nothing was released yet: the first
#             release is tagged by hand.
set -euo pipefail

releases() { git tag --list 'v*' "$@" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V || true; }

case "${1:-}" in
previous)
  releases --merged HEAD --no-contains HEAD | tail -n 1
  ;;
next)
  if [ -n "$(releases --points-at HEAD)" ]; then
    exit 0
  fi
  latest=$(releases --merged HEAD | tail -n 1)
  if [ -z "$latest" ]; then
    exit 0
  fi
  IFS=. read -r major minor patch <<<"${latest#v}"
  echo "v${major}.${minor}.$((patch + 1))"
  ;;
*)
  echo "usage: $0 previous|next" >&2
  exit 2
  ;;
esac
