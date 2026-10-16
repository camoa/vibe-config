#!/usr/bin/env bash
# Write or refresh the vibe-config-drupal block of standing rules in
# <project-folder>/AGENTS.md. Text outside the markers is left as it is.
set -euo pipefail

die() { echo "Error: $*" >&2; exit 1; }

[ $# -eq 1 ] || die "usage: $(basename "$0") <project-folder>"
[ -d "$1" ] || die "$1 is not a folder"

begin='<!-- BEGIN vibe-config-drupal -->'
end='<!-- END vibe-config-drupal -->'
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
  grep -qxF "$end" "$target" || die "$target has $begin but no $end; fix it by hand"
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
echo "Wrote the vibe-config-drupal block to $target"
