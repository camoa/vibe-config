#!/usr/bin/env bash
# Create a local Drupal backend: clone the template at a ref into a new
# folder, start it with DDEV, check the login page and print a login link.
set -euo pipefail

DEFAULT_SOURCE="https://github.com/camoa/vibe-config-drupal-backend.git"
DEFAULT_REF="main"
# An inherited CDPATH would make cd print a path or pick another folder.
CDPATH=
script_dir="$(cd "$(dirname "$0")" && pwd -P)"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--source <git URL or path>] [--ref <tag, branch or commit>] <project-folder>

Clones the backend template into <project-folder>, which must not exist or be
empty, then runs ddev start. The DDEV project name is the folder name. Run again
on a folder this script set up, it skips the clone and refreshes AGENTS.md.

Options:
  --source  Template git URL or local path. Default: $DEFAULT_SOURCE
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

# Resolve the folder to an absolute path, so a relative name never lands
# inside this skill when the script runs from the skill's own folder. pwd -P
# resolves symlinks on both sides of the comparison.
name="$(basename "$folder")"
case "$name" in
  .|..) die "name the project folder itself, not . or .." ;;
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
  git --git-dir="$folder/.git" remote get-url template >/dev/null 2>&1 \
    || die "$folder exists and is not empty; choose a new folder"
  rerun=1
fi
command -v ddev >/dev/null 2>&1 \
  || die "ddev is not installed; run the machine-check skill to set it up"

# --branch takes a branch or tag. A commit hash skips it, so git prints no
# "Remote branch not found" before the full clone and checkout.
if [ -n "$rerun" ]; then
  :
elif [[ "$ref" =~ ^[0-9a-f]{7,40}$ ]] || ! git clone --branch "$ref" "$source_repo" "$folder"; then
  made_folder=""
  [ -e "$folder" ] || made_folder=1
  git clone "$source_repo" "$folder" || die "git clone of $source_repo failed"
  if ! git -C "$folder" checkout "$ref"; then
    # Remove only the clone this run made, so a rerun with a good ref starts clean.
    if [ -n "$made_folder" ]; then
      rm -rf -- "$folder"
    else
      find "$folder" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    fi
    die "ref $ref not found in $source_repo; the clone was removed, so run setup again with a valid --ref"
  fi
fi
cd "$folder"
if [ -z "$rerun" ]; then
  # The project sits on a local main that tracks nothing, so the person's
  # commits land on a branch and they can add their own origin.
  git switch -q -C main
  # The clone may leave its default or cloned branch beside main; no local
  # branch keeps tracking the template.
  # git branch -d removes a branch that main or the branch's own upstream
  # holds; a branch neither holds stays, with no upstream.
  git for-each-ref --format='%(refname:short)' refs/heads/ | while read -r b; do
    [ "$b" = main ] && continue
    git branch -q -d "$b" 2>/dev/null || git branch --unset-upstream "$b" 2>/dev/null || true
  done
  git branch --unset-upstream main 2>/dev/null || true
  git remote rename origin template
fi

# ddev start runs the template's init.sh, which installs Drupal; its output
# passes through so WARNING and ERROR lines stay visible.
ddev start || die "ddev start failed; see the output above"

# shellcheck disable=SC2016 # expands inside the web container
site_url="$(ddev exec 'echo $DDEV_PRIMARY_URL' | tr -d '\r')" \
  || die "could not read the site URL from the DDEV container"
status="$(curl -sk -o /dev/null -w '%{http_code}' "$site_url/user/login" || true)"
[ "$status" = "200" ] || die "login page $site_url/user/login answered $status, not 200"
"$script_dir/write-agents-block.sh" .
"$script_dir/install-drupal-skills.sh" .

login_link="$(ddev drush user:login | tr -d '\r')" \
  || die "ddev drush user:login failed; the site is up at $site_url"
echo "Site URL: $site_url"
echo "Login link: $login_link"
