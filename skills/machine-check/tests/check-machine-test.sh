#!/usr/bin/env bash
# Runs check-machine.sh with stub commands first on PATH. Exits 0 when all cases pass.
here=$(cd "$(dirname "$0")" && pwd)
script="$here/../scripts/check-machine.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

# Every run that prints JSON must parse. bash:3.2 has neither parser, so only there it is skipped.
if command -v python3 >/dev/null 2>&1; then parser=python3
elif command -v jq >/dev/null 2>&1; then parser=jq
else parser=none; echo "note: JSON parse check skipped (neither python3 nor jq is on PATH)"
fi
check_json() { # label
  case "$parser" in
    python3) printf '%s' "$out" | python3 -m json.tool >/dev/null 2>&1 || { echo "FAIL $1: invalid JSON: $out"; fail=1; } ;;
    jq) printf '%s' "$out" | jq . >/dev/null 2>&1 || { echo "FAIL $1: invalid JSON: $out"; fail=1; } ;;
  esac
}

stub() { # name body
  printf '#!/bin/sh\n%s\n' "$2" > "$tmp/bin/$1"
  chmod +x "$tmp/bin/$1"
}

run_case() { # label expected_os uname_s uname_r
  rm -rf "${tmp:?}/bin"; mkdir "$tmp/bin"
  stub uname "if [ \"\$1\" = -s ]; then echo $3; else echo $4; fi"
  out=$(PATH="$tmp/bin:$PATH" WSL_DISTRO_NAME="" bash "$script"); code=$?
  if [ -r /proc/sys/fs/binfmt_misc/WSLInterop ] && [ "$2" = linux ]; then return; fi
  check_json "$1"
  case "$out" in
    *"\"os\":\"$2\""*) ;;
    *) echo "FAIL $1: expected os $2, got $out"; fail=1 ;;
  esac
  [ "$code" = 0 ] || { echo "FAIL $1: exit $code"; fail=1; }
}

run_case macos macos Darwin 23.0.0
run_case wsl2 wsl2 Linux 5.15.0-Microsoft-standard-WSL2
run_case linux linux Linux 6.1.0-generic

# Isolated runs: PATH holds only sed, tr and the stubs a case adds, so nothing real leaks in.
iso_start() { # uname_s
  mkdir -p "$tmp/bin"; rm -f "$tmp"/bin/*
  ln -s "$(command -v sed)" "$tmp/bin/sed"; ln -s "$(command -v tr)" "$tmp/bin/tr"
  stub uname "if [ \"\$1\" = -s ]; then echo $1; else echo 6.1.0-generic; fi"
}
iso_run() { out=$(PATH="$tmp/bin" WSL_DISTRO_NAME="" "$BASH" "$script"); check_json "isolated run"; }
expect() { # label substring
  case "$out" in
    *"$2"*) ;;
    *) echo "FAIL $1: wanted $2, got $out"; fail=1 ;;
  esac
}
refuse() { # label substring
  case "$out" in
    *"$2"*) echo "FAIL $1: unwanted $2 in $out"; fail=1 ;;
  esac
}
ddev_json='{"msg":"table","raw":{"DDEV version":"v1.25.4","docker-platform":"orbstack"}}'

iso_start Linux; stub ddev "case \"\$1\" in version) echo '$ddev_json' ;; utility) exit 0 ;; esac"
iso_run
expect "ddev ok" '"container":{"running":true,"provider":"orbstack","via":"ddev-dockercheck"}'
expect "ddev version" '"ddev":{"installed":true,"version":"v1.25.4"}'

iso_start Linux; stub ddev "case \"\$1\" in version) echo '$ddev_json' ;; utility) exit 1 ;; esac"
iso_run
expect "dockercheck fails" '"container":{"running":false,"provider":"orbstack","via":"ddev-dockercheck"}'

iso_start Linux; stub docker 'echo "Operating System: Docker Desktop"'
iso_run
expect "docker info ok" '"container":{"running":true,"provider":"docker-desktop","via":"docker-info"}'
expect "no ddev" '"ddev":{"installed":false,"version":""}'

iso_start Linux; stub docker 'echo "Operating System: Ubuntu"'
iso_run
expect "docker unknown provider" '"provider":"unknown","via":"docker-info"'

iso_start Linux; stub docker 'exit 1'
iso_run
expect "docker stopped" '"container":{"running":false,"provider":"unknown","via":"docker-info"}'
expect "docker stopped step" 'Run: sudo systemctl start docker. Then run this check again.","person_runs":true'

iso_start Linux
iso_run
expect "no docker" '"container":{"running":false,"provider":"none","via":"none"}'
expect "no node" '"node":{"installed":false,"version":""},"npm":{"installed":false,"version":""}'

iso_start Linux; stub node 'echo v22.14.0'; stub npm 'echo 11.6.0'
iso_run
expect "node version" '"node":{"installed":true,"version":"v22.14.0"},"npm":{"installed":true,"version":"11.6.0"}'

# Next steps with nothing installed.
for os in Darwin Linux; do
  iso_start $os; iso_run
  for piece in container ddev node npm; do expect "$os step $piece" "\"piece\":\"$piece\""; done
  refuse "$os brew" "brew"
  refuse "$os sudo" "sudo"
done
iso_start Darwin; iso_run
expect "macos container person" 'docker-installation/ describes, then open it once.","person_runs":true'
expect "macos ddev person" 'the macOS steps at https://docs.ddev.com/en/stable/users/install/ddev-installation/","person_runs":true'
expect "macos node person" 'https://nodejs.org/en/download","person_runs":true'
stub uname "if [ \"\$1\" = -s ]; then echo Linux; else echo 5.15.0-Microsoft-standard-WSL2; fi"; iso_run
for piece in container ddev node npm; do expect "wsl2 step $piece" "\"piece\":\"$piece\""; done
expect "wsl2 container person" 'installs Docker CE inside WSL2.","person_runs":true'
expect "wsl2 ddev person" 'ddev-installation/ describes.","person_runs":true'
expect "wsl2 node agent" 'nvm install --lts","person_runs":false'
refuse "wsl2 brew" "brew"

# Summary mode and the forbidden-pattern check.
summary=$(bash "$script" --summary); [ -n "$summary" ] || { echo "FAIL summary empty"; fail=1; }
case "$summary" in *[Hh]ard*|*unusual*) echo "FAIL summary warns about difficulty"; fail=1 ;; esac
if grep -nE '\bjq\b|brew |declare -A|mapfile|readarray|\$\{[a-z_]+(,,|\^\^|,|\^)\}|readlink -f|sed -i|grep -P' "$script" | grep -v '^[0-9]*:#'; then
  echo "FAIL forbidden pattern in script"; fail=1
fi
# sudo may appear only inside a step's text, never as a command the script runs.
if grep -n 'sudo ' "$script" | grep -v '^[0-9]*:#' | grep -v 'add_step '; then
  echo "FAIL script runs sudo"; fail=1
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
