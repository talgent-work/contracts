#!/usr/bin/env bash
# release-version.sh answers, for the pushed master commit, which release the
# breaking check compares against and which tag the commit receives.
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
git_() { git -C "$repo" -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c tag.gpgsign=false "$@"; }
query() { (cd "$repo" && bash "$root_dir/scripts/ci/release-version.sh" "$1"); }
expect() {
  local got
  got=$(query "$1")
  [ "$got" = "$2" ] || { echo "$3: $1: expected '$2', got '$got'" >&2; exit 1; }
}
commit() { git_ commit -q --allow-empty -m "$1"; }

git_ init -q -b master
commit first
expect previous "" "no release yet"
expect next "" "the first release is tagged by hand, never guessed"

git_ tag -a v0.1.0 -m v0.1.0
expect previous "" "a hand-tagged first release has nothing before it"
expect next "" "a commit already released is not tagged again"

commit second
expect previous v0.1.0 "the latest release before the commit"
expect next v0.1.1 "every push releases the next patch"

git_ tag -a v0.1.1 -m v0.1.1
commit third
commit fourth
expect previous v0.1.1 "several commits pushed at once"
expect next v0.1.2 "one patch for the whole push"

# Version order, not text order; tags that are not vX.Y.Z are ignored.
for tag in v0.1.10 v0.1.9 marketplace-v9.9.9 v1.0.0-rc1; do git_ tag -a "$tag" -m "$tag" HEAD~1; done
expect previous v0.1.10 "version order"
expect next v0.1.11 "version order"

# A minor tag made by hand restarts the patch count.
git_ tag -a v0.2.0 -m v0.2.0
expect previous v0.1.10 "a hand-tagged minor is checked against the release before it"
expect next "" "a hand-tagged minor is the commit's release"
commit fifth
expect previous v0.2.0 "after a hand-tagged minor"
expect next v0.2.1 "after a hand-tagged minor"

# Both tags on one commit: CI released a patch, then a minor was tagged by hand.
git_ tag -a v0.2.1 -m v0.2.1
git_ tag -a v0.3.0 -m v0.3.0
commit sixth
expect previous v0.3.0 "the highest tag on a commit"
expect next v0.3.1 "the highest tag on a commit"

# A tag on a commit outside master's history is not a master release.
git_ checkout -q -b side
commit side
git_ tag -a v9.0.0 -m v9.0.0
git_ checkout -q master
expect previous v0.3.0 "tags outside the commit's history"
expect next v0.3.1 "tags outside the commit's history"

if (cd "$repo" && bash "$root_dir/scripts/ci/release-version.sh" bogus 2>/dev/null); then
  echo "an unknown query must fail" >&2
  exit 1
fi
echo "release-version: ok"
