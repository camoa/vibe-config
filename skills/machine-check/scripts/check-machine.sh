#!/usr/bin/env bash
# Checks this machine for what a local Drupal site needs.
# Prints one JSON object on stdout, or a plain summary with --summary.
# Exit 0 whenever the check itself ran. No jq, Homebrew or GNU-only tools.

mode=json
case "${1:-}" in
  --summary) mode=summary ;;
  "") ;;
  *) echo "usage: check-machine.sh [--summary]" >&2; exit 2 ;;
esac

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n\t' '  '
}

detect_os() {
  local kernel release
  kernel=$(uname -s 2>/dev/null)
  case "$kernel" in
    Darwin) echo macos ;;
    Linux)
      release=$(uname -r 2>/dev/null | tr '[:upper:]' '[:lower:]')
      case "$release" in
        *microsoft*) echo wsl2; return ;;
      esac
      if [ -n "${WSL_DISTRO_NAME:-}" ] || [ -r /proc/sys/fs/binfmt_misc/WSLInterop ]; then
        echo wsl2
      else
        echo linux
      fi
      ;;
    *) echo unsupported ;;
  esac
}

have() { command -v "$1" >/dev/null 2>&1; }

os=$(detect_os)

# Container runtime: installed and running.
runtime=none
if have docker; then runtime=docker; fi
runtime_running=false
if [ "$runtime" = docker ] && docker info >/dev/null 2>&1; then runtime_running=true; fi
ddev_installed=false; have ddev && ddev_installed=true
node_installed=false; have node && node_installed=true
npm_installed=false; have npm && npm_installed=true

ready=false
if [ "$os" != unsupported ] && [ "$runtime_running" = true ] && [ "$ddev_installed" = true ] \
  && [ "$node_installed" = true ] && [ "$npm_installed" = true ]; then
  ready=true
fi

steps=""
add_step() { # piece step person_runs
  local item
  item=$(printf '{"piece":"%s","step":"%s","person_runs":%s}' \
    "$(json_escape "$1")" "$(json_escape "$2")" "$3")
  if [ -z "$steps" ]; then steps=$item; else steps="$steps,$item"; fi
}

if [ "$os" = unsupported ]; then
  add_step os "This operating system is not supported. Use macOS, Windows with WSL2, or Linux." true
fi
if [ "$runtime_running" != true ]; then
  if [ "$runtime" = none ]; then
    add_step container_runtime "Install a container runtime such as Docker Desktop, then start it." true
  else
    add_step container_runtime "Start the container runtime." true
  fi
fi
[ "$ddev_installed" = true ] || add_step ddev "Install DDEV." true
[ "$node_installed" = true ] || add_step node "Install Node.js." true
[ "$npm_installed" = true ] || add_step npm "Install npm, which comes with Node.js." true

checks=$(printf '{"container_runtime":{"name":"%s","installed":%s,"running":%s},"ddev":{"installed":%s},"node":{"installed":%s},"npm":{"installed":%s}}' \
  "$runtime" "$([ "$runtime" != none ] && echo true || echo false)" "$runtime_running" \
  "$ddev_installed" "$node_installed" "$npm_installed")

if [ "$mode" = json ]; then
  printf '{"os":"%s","ready":%s,"checks":%s,"next_steps":[%s]}\n' "$os" "$ready" "$checks" "$steps"
else
  echo "Operating system: $os"
  echo "Container runtime: $runtime (running: $runtime_running)"
  echo "DDEV installed: $ddev_installed"
  echo "Node.js installed: $node_installed; npm installed: $npm_installed"
  if [ "$ready" = true ]; then
    echo "Ready: yes. Nothing more to install."
  else
    echo "Ready: no. Next steps:"
    printf '%s\n' "$steps" | sed -e 's/},{/}\
{/g' | sed -e 's/.*"piece":"\([^"]*\)","step":"\([^"]*\)".*/- \1: \2/'
  fi
fi
exit 0
