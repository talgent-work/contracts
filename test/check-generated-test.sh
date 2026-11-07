#!/usr/bin/env bash
# check-generated.sh fails whenever the committed gen/ is not exactly what the
# committed protos generate: stale, extra or missing files.
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git_() { git -C "$repo" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }

# Each case starts from a committed copy of this repository's contracts.
fresh() {
  repo="$work/$1"
  mkdir -p "$repo"
  cp -r "$root_dir"/{proto,gen,scripts,buf.yaml,buf.gen.yaml,go.mod,go.sum} "$repo"
  git_ init -q -b master
  git_ add -A
  git_ commit -q -m base
}
check() { (cd "$repo" && bash scripts/ci/check-generated.sh >/dev/null 2>&1); }
expect_pass() { check || { echo "$1: expected the check to pass" >&2; exit 1; }; }
expect_fail() { if check; then echo "$1: expected the check to fail" >&2; exit 1; fi; }

fresh current
expect_pass "gen/ generated from the committed protos"

fresh stale
sed -i 's|^// FileKind tells an Attachment from an Artifact.|// FileKind tells an Attachment from an Artifact, changed.|' \
  "$repo/proto/storage/integration/v1/file_changed.proto"
git_ commit -q -am "proto changed without regenerating"
expect_fail "a proto changed without regenerating"

fresh extra
echo "package v1" >"$repo/gen/storage/integration/v1/stray.go"
git_ add -A
git_ commit -q -m "a file no proto generates"
expect_fail "a file no proto generates"

fresh missing
git_ rm -q gen/storage/integration/v1/file_changed.pb.go
git_ commit -q -m "a generated file deleted"
expect_fail "a generated file deleted"

echo "check-generated: ok"
