#!/usr/bin/env bash
# Install the drupal-ddev and drupal-config-mgmt skills from
# grasmash/drupal-claude-skills (MIT) at a pinned ref into a project's
# .claude/skills. Their install.sh takes no ref, so this follows their README's
# manual route (clone, copy skills/*) at a fixed commit.
set -euo pipefail

DRUPAL_SKILLS_REPO="https://github.com/grasmash/drupal-claude-skills.git"
DRUPAL_SKILLS_REF="19514f411a710949ff7ab65b01f1027cb832c5d7"
skills=(drupal-ddev drupal-config-mgmt)

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--ref <commit or tag>] <project-folder>

Copies ${skills[*]} from $DRUPAL_SKILLS_REPO
into <project-folder>/.claude/skills/, replacing earlier copies, and records the
repo URL and commit in .claude/skills/drupal-claude-skills.pin.

Options:
  --ref   Commit or tag. Default: $DRUPAL_SKILLS_REF
  --help  Print this help.
USAGE
}

die() { echo "Error: $*" >&2; exit 1; }

ref="$DRUPAL_SKILLS_REF"
folder=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) [ $# -ge 2 ] || die "--ref needs a value"; ref="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    -*) usage >&2; die "unknown option: $1" ;;
    *) [ -z "$folder" ] || die "only one project folder allowed"; folder="$1"; shift ;;
  esac
done
[ -n "$folder" ] || { usage >&2; die "no project folder given"; }
[ -d "$folder" ] || die "$folder is not a folder"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp"
git -C "$tmp" fetch -q --depth 1 "$DRUPAL_SKILLS_REPO" "$ref" \
  || die "could not fetch $ref from $DRUPAL_SKILLS_REPO"
git -C "$tmp" checkout -q FETCH_HEAD
commit="$(git -C "$tmp" rev-parse HEAD)"

dest="$folder/.claude/skills"
for skill in "${skills[@]}"; do
  [ -f "$tmp/skills/$skill/SKILL.md" ] || die "$skill/SKILL.md not found at $ref"
done
mkdir -p "$dest"
for skill in "${skills[@]}"; do
  rm -rf "${dest:?}/$skill"
  cp -R "$tmp/skills/$skill" "$dest/$skill"
  # MIT asks that the licence travel with each copy.
  cp "$tmp/LICENSE" "$dest/$skill/LICENSE"
done
printf 'repo: %s\ncommit: %s\n' "$DRUPAL_SKILLS_REPO" "$commit" > "$dest/drupal-claude-skills.pin"
echo "Installed ${skills[*]} at $commit into $dest"
