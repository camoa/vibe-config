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

# Container runtime: ddev's own check when ddev exists, else docker info.
ddev_installed=false; ddev_version=""; ddev_platform=""
if have ddev; then
  ddev_installed=true
  ddev_json=$(ddev version -j 2>/dev/null)
  ddev_version=$(printf '%s' "$ddev_json" | sed -n 's/.*"DDEV version":"\([^"]*\)".*/\1/p')
  ddev_platform=$(printf '%s' "$ddev_json" | sed -n 's/.*"docker-platform":"\([^"]*\)".*/\1/p')
fi
runtime_running=false; provider=none; via=none
if [ "$ddev_installed" = true ]; then
  via=ddev-dockercheck
  provider=${ddev_platform:-unknown}
  if ddev utility dockercheck >/dev/null 2>&1; then runtime_running=true; fi
elif have docker; then
  via=docker-info
  provider=unknown
  if docker_out=$(docker info 2>/dev/null); then
    runtime_running=true
    docker_os=$(printf '%s' "$docker_out" | tr '[:upper:]' '[:lower:]')
    case "$docker_os" in
      *orbstack*) provider=orbstack ;;
      *colima*) provider=colima ;;
      *"docker desktop"*) provider=docker-desktop ;;
    esac
  fi
fi
runtime_known=false
{ [ "$provider" != none ] && [ "$provider" != unknown ]; } && runtime_known=true
have docker && runtime_known=true
node_installed=false; node_version=""
if have node; then node_installed=true; node_version=$(node -v 2>/dev/null); fi
node_major=${node_version#v}; node_major=${node_major%%.*}
node_ok=false
case "$node_major" in
  ''|*[!0-9]*) ;;
  *) [ "$node_major" -ge 24 ] && node_ok=true ;;
esac
npm_installed=false; npm_version=""
if have npm; then npm_installed=true; npm_version=$(npm -v 2>/dev/null); fi

ready=false
if [ "$os" != unsupported ] && [ "$runtime_running" = true ] && [ "$ddev_installed" = true ] \
  && [ "$node_ok" = true ] && [ "$npm_installed" = true ]; then
  ready=true
fi

steps=""
add_step() { # piece step person_runs
  local item
  item=$(printf '{"piece":"%s","step":"%s","person_runs":%s}' \
    "$(json_escape "$1")" "$(json_escape "$2")" "$3")
  if [ -z "$steps" ]; then steps=$item; else steps="$steps,$item"; fi
}

# Steps are text only: nothing here installs or starts anything.
if [ "$os" = unsupported ]; then
  add_step os "This operating system is not supported. Use macOS, Windows with WSL2, or Linux." true
fi
if [ "$runtime_running" != true ]; then
  case "$os:$runtime_known" in
    macos:true) add_step container "Start your container app and wait until it runs. In Terminal run one of: open -a OrbStack, open -a Docker (Docker Desktop), colima start (Colima)." true ;;
    macos:*) add_step container "Install OrbStack or Docker Desktop as https://docs.ddev.com/en/stable/users/install/docker-installation/ describes, then open it once." true ;;
    wsl2:true) add_step container "Inside WSL2 run: sudo systemctl start docker. Then run this check again." true ;;
    wsl2:*) add_step container "Run the DDEV Windows installer from Windows, as https://docs.ddev.com/en/stable/users/install/ddev-installation/ describes. It also installs Docker CE inside WSL2." true ;;
    *:true) add_step container "Run: sudo systemctl start docker. Then run this check again." true ;;
    *) add_step container "Install Docker CE as https://docs.ddev.com/en/stable/users/install/docker-installation/ describes for Linux, add yourself to the docker group, then log in again." true ;;
  esac
fi
if [ "$ddev_installed" != true ]; then
  case "$os" in
    macos) add_step ddev "In Terminal run: curl -fsSL https://ddev.com/install.sh | bash. It may ask for your password." true ;;
    wsl2) add_step ddev "Run the DDEV Windows installer from Windows, as https://docs.ddev.com/en/stable/users/install/ddev-installation/ describes." true ;;
    *) add_step ddev "Install DDEV with the Linux steps at https://docs.ddev.com/en/stable/users/install/ddev-installation/" true ;;
  esac
fi
if [ "$node_installed" != true ]; then
  if [ "$os" = macos ]; then
    add_step node "Install Node.js with the installer from https://nodejs.org/en/download" true
  else
    add_step node "Install nvm from https://github.com/nvm-sh/nvm, then run: nvm install --lts" false
  fi
elif [ "$node_ok" != true ]; then
  node_old="Node.js $node_version is too old; Node.js 24 LTS or later is needed. Install the LTS from https://nodejs.org/en/download, or run nvm install --lts (nvm) or fnm install --lts (fnm)."
  if [ "$os" = macos ]; then add_step node "$node_old" true; else add_step node "$node_old" false; fi
fi
if [ "$npm_installed" != true ]; then
  if [ "$os" = macos ]; then
    add_step npm "Reinstall Node.js with the installer from https://nodejs.org/en/download. It includes npm." true
  else
    add_step npm "Run: nvm install --lts. It installs npm with Node.js (nvm: https://github.com/nvm-sh/nvm)." false
  fi
fi

checks=$(printf '{"container":{"running":%s,"provider":"%s","via":"%s"},"ddev":{"installed":%s,"version":"%s"},"node":{"installed":%s,"version":"%s"},"npm":{"installed":%s,"version":"%s"}}' \
  "$runtime_running" "$(json_escape "$provider")" "$via" \
  "$ddev_installed" "$(json_escape "$ddev_version")" \
  "$node_installed" "$(json_escape "$node_version")" "$npm_installed" "$(json_escape "$npm_version")")

if [ "$mode" = json ]; then
  printf '{"os":"%s","ready":%s,"checks":%s,"next_steps":[%s]}\n' "$os" "$ready" "$checks" "$steps"
else
  echo "Operating system: $os"
  echo "Container runtime: $provider (running: $runtime_running)"
  echo "DDEV installed: $ddev_installed"
  echo "Node.js installed: $node_installed${node_major:+ (major $node_major, needs 24 or later)}; npm installed: $npm_installed"
  if [ "$ready" = true ]; then
    echo "Ready: yes. Nothing more to install."
  else
    echo "Ready: no. Next steps:"
    printf '%s\n' "$steps" | sed -e 's/},{/}\
{/g' | sed -e 's/.*"piece":"\([^"]*\)","step":"\([^"]*\)".*/- \1: \2/'
  fi
fi
exit 0
