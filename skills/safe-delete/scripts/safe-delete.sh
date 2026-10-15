#!/usr/bin/env bash
# Delete one DDEV project after the person types its name.
# Usage: safe-delete.sh [--no-snapshot] [--remove-folder PATH] PROJECT
# Exit 0 deleted; 2 usage error, no terminal, wrong name or refused folder; 1 a ddev call failed.
# Portable to bash 3.2 and BSD tools.

usage() {
  echo "Usage: safe-delete.sh [--no-snapshot] [--remove-folder PATH] PROJECT" >&2
  exit 2
}

snapshot=1
folder=""
project=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-snapshot) snapshot=0 ;;
    --remove-folder)
      [ $# -ge 2 ] || usage
      folder="$2"
      shift
      ;;
    -*) usage ;;
    *)
      [ -z "$project" ] || usage
      project="$1"
      ;;
  esac
  shift
done
[ -n "$project" ] || usage

if [ ! -t 0 ]; then
  echo "Refusing: no terminal. A person must type the project name to confirm." >&2
  exit 2
fi

stamp=$(date -u +%Y%m%dT%H%M%SZ)
snapshot_name="safe-delete-$stamp"
kept=""

if [ -n "$folder" ]; then
  if [ ! -f "$folder/.ddev/config.yaml" ]; then
    echo "Refusing: $folder has no .ddev/config.yaml." >&2
    exit 2
  fi
  folder=$(cd "$folder" && pwd -P) || exit 2
  if [ "$folder" = "/" ] || [ "$folder" = "$(cd "$HOME" && pwd -P)" ]; then
    echo "Refusing to remove $folder." >&2
    exit 2
  fi
  cfg_name=$(grep '^name:' "$folder/.ddev/config.yaml" | head -n 1 | sed -e 's/^name:[[:space:]]*//' -e 's/[[:space:]]*$//' -e "s/^[\"']//" -e "s/[\"']\$//")
  [ -n "$cfg_name" ] || cfg_name=$(basename "$folder")
  if [ "$cfg_name" != "$project" ]; then
    echo "Refusing: $folder belongs to project '$cfg_name', not '$project'." >&2
    exit 2
  fi
  if [ "$snapshot" = 1 ]; then
    kept="$(dirname "$folder")/$project-db-snapshots-$stamp"
  fi
fi

echo "This deletes the DDEV project: $project"
echo "Database: the database of $project is removed."
if [ "$snapshot" = 1 ]; then
  echo "A database snapshot named $snapshot_name is taken first. It covers the database only, not files or code."
else
  echo "No snapshot is taken."
fi
if [ -n "$folder" ]; then
  echo "Folder: $folder is removed."
  [ -z "$kept" ] || echo "Snapshots are moved to $kept first."
fi
printf 'Type the project name to confirm: '
answer=""
IFS= read -r answer
if [ "$answer" != "$project" ]; then
  echo "Name did not match. Nothing was deleted." >&2
  exit 2
fi

if [ "$snapshot" = 1 ]; then
  # ddev can print "Failed to snapshot" and still exit 0, so confirm the snapshot is listed.
  ddev snapshot --name "$snapshot_name" "$project" || { echo "Snapshot failed. Nothing was deleted." >&2; exit 1; }
  ddev snapshot --list "$project" 2>/dev/null | grep -q "$snapshot_name" || { echo "Snapshot not found. Nothing was deleted." >&2; exit 1; }
fi
ddev delete --omit-snapshot --yes "$project" || { echo "ddev delete failed." >&2; exit 1; }
echo "Deleted project $project."

if [ -n "$folder" ]; then
  if [ -n "$kept" ]; then
    [ -d "$folder/.ddev/db_snapshots" ] || { echo "No snapshots found in the folder; folder kept." >&2; exit 1; }
    mv "$folder/.ddev/db_snapshots" "$kept" || { echo "Could not move snapshots; folder kept." >&2; exit 1; }
    echo "Snapshots kept in $kept"
  fi
  rm -rf "$folder" || exit 1
  echo "Removed folder $folder."
fi
exit 0
