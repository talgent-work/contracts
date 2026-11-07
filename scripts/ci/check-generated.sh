#!/usr/bin/env bash
# Regenerates gen/ from proto/ and fails unless the result is exactly what is
# committed: no changed, added or removed file.
set -euo pipefail

buf generate
changes=$(git status --porcelain --untracked-files=all -- gen)
if [ -n "$changes" ]; then
  echo "gen/ is out of sync with proto/. Run 'buf generate' and commit the result:" >&2
  echo "$changes" >&2
  exit 1
fi
