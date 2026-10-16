#!/usr/bin/env bash
# Create a local Drupal backend: clone the template at a pinned ref into a new
# folder, start it with DDEV, check the home page and print a login link.
set -euo pipefail

# Placeholder until the template is published; pass --source meanwhile.
DEFAULT_SOURCE="https://github.com/OWNER/vibe-config-drupal-backend.git"
DEFAULT_REF="1cd1bb525327ffdfb7b5cf8ea0e48325b5b4b500"
script_dir="$(cd "$(dirname "$0")" && pwd)"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--source <git URL or path>] [--ref <tag, branch or commit>] <project-folder>

Clones the backend template into <project-folder>, which must not exist or be
empty, then runs ddev start. The DDEV project name is the folder name.

Options:
  --source  Template git URL or local path. Default: $DEFAULT_SOURCE
            (a placeholder until the template is published; pass --source).
  --ref     Template tag, branch or commit. Default: $DEFAULT_REF
  --help    Print this help.
USAGE
}

die() { echo "Error: $*" >&2; exit 1; }

source_repo="$DEFAULT_SOURCE"
ref="$DEFAULT_REF"
folder=""
while [ $# -gt 0 ]; do
  case "$1" in
    --source) [ $# -ge 2 ] || die "--source needs a value"; source_repo="$2"; shift 2 ;;
    --ref) [ $# -ge 2 ] || die "--ref needs a value"; ref="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    -*) usage >&2; die "unknown option: $1" ;;
    *) [ -z "$folder" ] || die "only one project folder allowed"; folder="$1"; shift ;;
  esac
done
[ -n "$folder" ] || { usage >&2; die "no project folder given"; }

if [ -e "$folder" ] && [ -n "$(ls -A "$folder" 2>/dev/null)" ]; then
  die "$folder exists and is not empty; choose a new folder"
fi
command -v ddev >/dev/null 2>&1 \
  || die "ddev is not installed; run the machine-check skill to set it up"

# --branch takes a branch or tag. A commit hash skips it, so git prints no
# "Remote branch not found" before the full clone and checkout.
if [[ "$ref" =~ ^[0-9a-f]{7,40}$ ]] || ! git clone --branch "$ref" "$source_repo" "$folder"; then
  git clone "$source_repo" "$folder" || die "git clone of $source_repo failed"
  git -C "$folder" checkout "$ref" || die "ref $ref not found in $source_repo"
fi
cd "$folder"
git remote rename origin template

# ddev start runs the template's init.sh, which installs Drupal; its output
# passes through so WARNING and ERROR lines stay visible.
ddev start || die "ddev start failed; see the output above"

# shellcheck disable=SC2016 # expands inside the web container
site_url="$(ddev exec 'echo $DDEV_PRIMARY_URL' | tr -d '\r')" \
  || die "could not read the site URL from the DDEV container"
status="$(curl -sk -o /dev/null -w '%{http_code}' "$site_url" || true)"
[ "$status" = "200" ] || die "home page $site_url answered $status, not 200"
"$script_dir/write-agents-block.sh" .

login_link="$(ddev drush user:login | tr -d '\r')" \
  || die "ddev drush user:login failed; the site is up at $site_url"
echo "Site URL: $site_url"
echo "Login link: $login_link"
