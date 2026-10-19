#!/usr/bin/env bash
# Write or refresh the vibe-config block of standing rules in
# <project-folder>/AGENTS.md. Text outside the markers is left as it is.
set -euo pipefail

die() { echo "Error: $*" >&2; exit 1; }

[ $# -eq 1 ] || die "usage: $(basename "$0") <project-folder>"
[ -d "$1" ] || die "$1 is not a folder"

begin='<!-- BEGIN vibe-config -->'
end='<!-- END vibe-config -->'
asset="$(dirname "$0")/../assets/agents-block.md"
target="$1/AGENTS.md"

BLOCK="$(awk -v b="$begin" -v e="$end" '$0 == b { on = 1 } on { print } $0 == e { exit }' "$asset")"
[ -n "$BLOCK" ] || die "no block found in $asset"
export BLOCK

if [ ! -e "$target" ]; then
  printf '%s\n' "$BLOCK" > "$target"
elif ! grep -qxF "$begin" "$target"; then
  # A blank line keeps the block apart from the text already there.
  if [ -s "$target" ]; then printf '\n' >> "$target"; fi
  printf '%s\n' "$BLOCK" >> "$target"
else
  awk -v b="$begin" -v e="$end" '$0 == b { on = 1 } on && $0 == e { found = 1; exit } END { exit !found }' "$target" \
    || die "$target has $begin but no $end after it; fix it by hand"
  tmp="$(mktemp "$target.XXXXXX")"
  awk -v b="$begin" -v e="$end" '
    $0 == b && !done { print ENVIRON["BLOCK"]; skip = 1; next }
    skip { if ($0 == e) { skip = 0; done = 1 } next }
    { print }
  ' "$target" > "$tmp"
  # cat, not mv, so AGENTS.md keeps its own file mode.
  cat "$tmp" > "$target"
  rm -f "$tmp"
fi
echo "Wrote the vibe-config block to $target"
