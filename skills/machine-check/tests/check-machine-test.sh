#!/usr/bin/env bash
# Runs check-machine.sh with stub commands first on PATH. Exits 0 when all cases pass.
here=$(cd "$(dirname "$0")" && pwd)
script="$here/../scripts/check-machine.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

stub() { # name body
  printf '#!/bin/sh\n%s\n' "$2" > "$tmp/bin/$1"
  chmod +x "$tmp/bin/$1"
}

run_case() { # label expected_os uname_s uname_r
  rm -rf "${tmp:?}/bin"; mkdir "$tmp/bin"
  stub uname "if [ \"\$1\" = -s ]; then echo $3; else echo $4; fi"
  out=$(PATH="$tmp/bin:$PATH" WSL_DISTRO_NAME="" bash "$script"); code=$?
  if [ -r /proc/sys/fs/binfmt_misc/WSLInterop ] && [ "$2" = linux ]; then return; fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$out" | python3 -m json.tool >/dev/null || { echo "FAIL $1: invalid JSON"; fail=1; }
  fi
  case "$out" in
    *"\"os\":\"$2\""*) ;;
    *) echo "FAIL $1: expected os $2, got $out"; fail=1 ;;
  esac
  [ "$code" = 0 ] || { echo "FAIL $1: exit $code"; fail=1; }
}

run_case macos macos Darwin 23.0.0
run_case wsl2 wsl2 Linux 5.15.0-Microsoft-standard-WSL2
run_case linux linux Linux 6.1.0-generic

# Summary mode and the forbidden-pattern check.
summary=$(bash "$script" --summary); [ -n "$summary" ] || { echo "FAIL summary empty"; fail=1; }
case "$summary" in *[Hh]ard*|*unusual*) echo "FAIL summary warns about difficulty"; fail=1 ;; esac
if grep -nE '\bjq\b|brew |\$\{[a-z_]+,,\}|readlink -f|sed -i|grep -P' "$script" | grep -v '^[0-9]*:#'; then
  echo "FAIL forbidden pattern in script"; fail=1
fi

# Re-run these cases under bash 3.2 when the image is already local. Never pull.
if [ -z "${IN_BASH32:-}" ]; then
  if command -v docker >/dev/null 2>&1 && docker image inspect bash:3.2 >/dev/null 2>&1; then
    docker run --rm --network none -e IN_BASH32=1 -v "$here/..:/mc:ro" bash:3.2 \
      bash /mc/tests/check-machine-test.sh || { echo "FAIL under bash:3.2"; fail=1; }
  else
    echo "note: bash:3.2 run skipped (docker or the bash:3.2 image is absent)"
  fi
fi

[ "$fail" = 0 ] && echo "all cases passed"
exit "$fail"
