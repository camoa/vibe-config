#!/usr/bin/env bash
# Create a Next.js app that signs in against a local Drupal backend: run
# create-next-app, lay the skill's app files over it, pin the login packages and
# write .env.local once.
set -euo pipefail

NEXT_VERSION="16.4.1"
OPENID_CLIENT_VERSION="6.8.8"
IRON_SESSION_VERSION="9.0.1"
# An inherited CDPATH would make cd print a path or pick another folder.
CDPATH=
script_dir="$(cd "$(dirname "$0")" && pwd -P)"

usage() {
  cat <<USAGE
Usage: $(basename "$0") --backend <backend-project-folder> <app-folder>

Creates a Next.js $NEXT_VERSION app in <app-folder>, which must not exist or be
empty, copies the skill's app files over it, pins openid-client and iron-session
and writes .env.local. Run again on an app it created, it skips create-next-app
and the package install, copies the app files again and leaves .env.local alone.

Options:
  --backend  Folder of the DDEV backend project (required).
  --help     Print this help.
USAGE
}

die() { echo "Error: $*" >&2; exit 1; }

backend=""
folder=""
while [ $# -gt 0 ]; do
  case "$1" in
    --backend) [ $# -ge 2 ] || die "--backend needs a value"; backend="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    -*) usage >&2; die "unknown option: $1" ;;
    *) [ -z "$folder" ] || die "only one app folder allowed"; folder="$1"; shift ;;
  esac
done
[ -n "$backend" ] || { usage >&2; die "--backend is required"; }
[ -n "$folder" ] || { usage >&2; die "no app folder given"; }

backend="$(cd "$backend" 2>/dev/null && pwd -P)" || die "backend folder not found: $backend"
name="$(basename "$folder")"
case "$name" in
  .|..) die "name the app folder itself, not . or .." ;;
esac
parent="$(cd "$(dirname "$folder")" 2>/dev/null && pwd -P)" \
  || die "the parent folder of $folder does not exist; create it first"
folder="$parent/$name"
if [ -d "$folder" ]; then folder="$(cd "$folder" && pwd -P)"; fi
skill_dir="$(cd "$script_dir/.." && pwd -P)"
case "$folder/" in
  "$skill_dir"/*) die "$folder is inside the skill folder $skill_dir; choose a folder outside it" ;;
esac

rerun=""
if [ -e "$folder" ] && [ -n "$(ls -A "$folder" 2>/dev/null)" ]; then
  grep -q '"openid-client"' "$folder/package.json" 2>/dev/null \
    || die "$folder exists and is not empty; choose a new folder"
  rerun=1
fi

# 1. Tools and backend.
command -v node >/dev/null 2>&1 || die "node is not installed"
node -e 'process.exit(Number(process.versions.node.split(".")[0])>=24?0:1)' \
  || die "Node.js 24 LTS or later is required; found $(node -v)"
command -v npm >/dev/null 2>&1 || die "npm is not installed"
command -v mkcert >/dev/null 2>&1 || die "mkcert is not installed; DDEV needs it, run the machine-check skill"
command -v ddev >/dev/null 2>&1 || die "ddev is not installed; run the machine-check skill to set it up"
# shellcheck disable=SC2016 # expands inside the web container
backend_url="$(cd "$backend" && ddev exec 'echo $DDEV_PRIMARY_URL' | tr -d '\r')" \
  || die "could not read the backend URL; is $backend a started DDEV project?"
status="$(curl -sk -o /dev/null -w '%{http_code}' "$backend_url" || true)"
# The oauth-login template denies its home page (403), so any answer counts.
[ "$status" != "000" ] || die "the backend $backend_url did not answer; start it with ddev start in $backend"

# 2. The app. Explicit flags and no --yes: --yes uses stored preferences.
if [ -z "$rerun" ]; then
  npx --yes "create-next-app@$NEXT_VERSION" "$folder" \
    --ts --app --eslint --tailwind --no-src-dir --use-npm --import-alias "@/*" </dev/null \
    || die "create-next-app failed; see the output above"
fi
cd "$folder"

# 3. The skill's app files, copied again on every run.
if [ -d "$skill_dir/assets/app" ]; then
  cp -R "$skill_dir/assets/app/." "$folder/"
fi

# 4 and 5. Pinned login packages, and a dev script that sets NODE_EXTRA_CA_CERTS
# before next dev starts, because Node reads the variable only at launch.
if [ -z "$rerun" ]; then
  npm install --save-exact "openid-client@$OPENID_CLIENT_VERSION" "iron-session@$IRON_SESSION_VERSION" \
    || die "npm install failed; see the output above"
  npm pkg set scripts.dev='export NODE_EXTRA_CA_CERTS="$(mkcert -CAROOT)/rootCA.pem"; next dev'
fi

# 6. The env file, written once.
if [ ! -e .env.local ]; then
  secret="$(openssl rand -hex 32)"
  cat > .env.local <<ENV
DRUPAL_BASE_URL=$backend_url
DRUPAL_CLIENT_ID=nextjs
DRUPAL_SCOPE=authenticated
APP_URL=http://localhost:3000
SESSION_SECRET=$secret
ENV
fi

# 7. The secrets must never be committed.
git check-ignore -q .env.local \
  || die ".env.local is not ignored by git; add it to .gitignore before you commit anything"

echo "App folder: $folder"
echo "Backend URL: $backend_url"
echo "Start command: cd $folder && npm run dev"
