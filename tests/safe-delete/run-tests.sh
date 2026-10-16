#!/usr/bin/env bash
# Test runner for safe-delete.sh with a fake ddev. Exit 0 when every case passes.
# shellcheck disable=SC2016,SC2034
# check evaluates its single-quoted condition later; rc is read there.
here=$(cd "$(dirname "$0")" && pwd -P)
script="$here/../../skills/safe-delete/scripts/safe-delete.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/safe-delete-test.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT
export PATH="$here/fake-bin:$PATH"
export FAKE_DDEV_LOG="$tmp/ddev.log"
export HOME="$tmp/home"
mkdir -p "$HOME"

if script --version 2>&1 | grep -q util-linux; then
  pty_form=linux
else
  pty_form=bsd
fi

fails=0
rc=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

# run_pty ANSWER ARGS...: run the script under a pseudo-terminal with ANSWER typed.
run_pty() {
  local answer="$1"
  shift
  : > "$FAKE_DDEV_LOG"; rm -f "$FAKE_DDEV_LOG.snapshots"
  if [ "$pty_form" = linux ]; then
    printf '%s\n' "$answer" | script -q -e -c "$(printf '%q ' bash "$script" "$@")" /dev/null > "$tmp/out" 2>&1
  else
    printf '%s\n' "$answer" | script -q /dev/null bash "$script" "$@" > "$tmp/out" 2>&1
  fi
  rc=$?
}

make_project() {
  rm -rf "$tmp/work"
  mkdir -p "$tmp/work/$1/.ddev/db_snapshots"
  printf 'name: %s\ntype: drupal\n' "$2" > "$tmp/work/$1/.ddev/config.yaml"
  : > "$tmp/work/$1/.ddev/db_snapshots/a.gz"
}

# No terminal
: > "$FAKE_DDEV_LOG"
bash "$script" demo < /dev/null > "$tmp/out" 2>&1; rc=$?
check "no terminal: exit 2" '[ $rc -eq 2 ]'
check "no terminal: says why" 'grep -qi "no terminal" "$tmp/out"'
check "no terminal: log empty" '[ ! -s "$FAKE_DDEV_LOG" ]'

: > "$FAKE_DDEV_LOG"
echo demo | bash "$script" demo > "$tmp/out" 2>&1; rc=$?
check "piped right name: exit 2" '[ $rc -eq 2 ]'
check "piped right name: log empty" '[ ! -s "$FAKE_DDEV_LOG" ]'

# Wrong answers
for ans in wrong "" y; do
  run_pty "$ans" demo
  check "answer '$ans': exit 2" '[ $rc -eq 2 ]'
  check "answer '$ans': log empty" '[ ! -s "$FAKE_DDEV_LOG" ]'
done

# Prompt content
run_pty wrong demo
check "prompt names project" 'grep -q "demo" "$tmp/out"'
check "prompt names database" 'grep -qi "database" "$tmp/out"'
check "prompt omits folder without flag" '! grep -qi "folder" "$tmp/out"'

# Confirmed run
run_pty demo demo
check "confirmed: exit 0" '[ $rc -eq 0 ]'
check "confirmed: snapshot before delete" '[ "$(sed -n 1p "$FAKE_DDEV_LOG" | grep -c "^snapshot --name safe-delete-[0-9]*T[0-9]*Z demo$")" = 1 ] && [ "$(sed -n 2p "$FAKE_DDEV_LOG")" = "delete --omit-snapshot --yes demo" ]'
check "confirmed: one delete line" '[ "$(grep -c "^delete" "$FAKE_DDEV_LOG")" = 1 ]'
check "confirmed: no --all" '! grep -q -- "--all" "$FAKE_DDEV_LOG"'

run_pty demo --no-snapshot demo
check "no-snapshot: exit 0" '[ $rc -eq 0 ]'
check "no-snapshot: no snapshot line" '! grep -q "^snapshot" "$FAKE_DDEV_LOG" && grep -q "^delete --omit-snapshot --yes demo$" "$FAKE_DDEV_LOG"'

FAKE_DDEV_FAIL_SNAPSHOT=1 run_pty demo demo
check "failed snapshot: exit 1" '[ $rc -eq 1 ]'
check "failed snapshot: no delete line" '! grep -q "^delete" "$FAKE_DDEV_LOG"'

FAKE_DDEV_SILENT_FAIL_SNAPSHOT=1 run_pty demo demo
check "silent failed snapshot: exit 1" '[ $rc -eq 1 ]'
check "silent failed snapshot: no delete line" '! grep -q "^delete" "$FAKE_DDEV_LOG"'

# Folder handling
make_project demo demo
run_pty demo demo
check "folder kept without flag" '[ -d "$tmp/work/demo" ]'

make_project demo demo
run_pty demo --remove-folder "$tmp/work/demo" demo
check "remove-folder: exit 0" '[ $rc -eq 0 ]'
check "remove-folder: prompt shows path" 'grep -q "$tmp/work/demo" "$tmp/out"'
check "remove-folder: folder gone" '[ ! -d "$tmp/work/demo" ]'
check "remove-folder: snapshots survive beside it" 'ls "$tmp"/work/demo-db-snapshots-*/a.gz > /dev/null 2>&1'

make_project demo other
run_pty demo --remove-folder "$tmp/work/demo" demo
check "mismatched folder: exit 2" '[ $rc -eq 2 ]'
check "mismatched folder: folder kept, log empty" '[ -d "$tmp/work/demo" ] && [ ! -s "$FAKE_DDEV_LOG" ]'

run_pty demo --remove-folder / demo
check "root refused: exit 2" '[ $rc -eq 2 ]'

run_pty demo --remove-folder "" demo
check "empty folder value: exit 2" '[ $rc -eq 2 ]'
check "empty folder value: says why" 'grep -q "needs a folder path" "$tmp/out"'
check "empty folder value: log empty" '[ ! -s "$FAKE_DDEV_LOG" ]'

if [ $fails -eq 0 ]; then
  echo "all passed"
  exit 0
fi
echo "$fails failed"
exit 1
