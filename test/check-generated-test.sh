#!/usr/bin/env bash
# check-generated.sh fails whenever the committed gen/ is not exactly what the
# committed protos generate, in any language: stale, extra or missing files.
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

# Generation also keeps the hand-written files of each language's package,
# such as gen/ts/package.json: a deleted one would fail this case.
fresh current
expect_pass "gen/ generated from the committed protos"

fresh stale
sed -i 's|^// FileOperation is how a file Storage wrote changed.|// FileOperation is how a file Storage wrote changed, differently.|' \
  "$repo/proto/storage/integration/v1/file_changed.proto"
git_ commit -q -am "proto changed without regenerating"
expect_fail "a proto changed without regenerating"

# Every language's tree is checked, not only the first one generated.
for lang in go ts; do
  case "$lang" in
  go) dir=gen/go/storage/integration/v1 file=file_changed.pb.go stray=stray.go ;;
  ts) dir=gen/ts/dist/storage/integration/v1 file=file_changed_pb.js stray=stray_pb.js ;;
  esac

  fresh "$lang-edited"
  echo "// edited by hand" >>"$repo/$dir/$file"
  git_ commit -q -am "a generated $lang file edited by hand"
  expect_fail "a generated $lang file edited by hand"

  fresh "$lang-extra"
  echo "// no proto generates this" >"$repo/$dir/$stray"
  git_ add -A
  git_ commit -q -m "a $lang file no proto generates"
  expect_fail "a $lang file no proto generates"

  fresh "$lang-missing"
  git_ rm -q "$dir/$file"
  git_ commit -q -m "a generated $lang file deleted"
  expect_fail "a generated $lang file deleted"
done

echo "check-generated: ok"
