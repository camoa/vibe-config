---
name: safe-delete
description: Use when a person asks to delete, remove, wipe or reset a DDEV project or its database. Covers the reset path (ddev snapshot restore) and the delete script the person runs in their own terminal.
---

# Safe delete

## Reset is a restore, never a delete

When the person wants to reset a site, run `ddev snapshot restore --latest`, or `ddev snapshot restore NAME` for a named snapshot. Do not delete the project to reset it.

A snapshot covers the database only. It does not cover `sites/default/files`, code or exported config. Say so when you offer a restore, and never imply files are backed up.

## Delete is the person's command

The agent never runs `ddev delete` and never runs the delete script itself. The script refuses to run without a terminal and asks the person to type the project name, so only the person can complete it.

Hand the person the exact command to run in their own terminal, with the project name filled in and the script's full path, resolved from this skill's own folder. A relative path fails from the project folder or when the skill is installed elsewhere:

```
FULL_PATH_TO_THIS_SKILL/scripts/safe-delete.sh PROJECT
```

Options:

- `--no-snapshot` skips the snapshot the script takes before deleting.
- `--remove-folder PATH` also removes the project folder, after moving its `.ddev/db_snapshots` to a sibling folder.

Exit codes: 0 deleted; 2 usage error, no terminal, wrong name or refused folder; 1 a ddev call failed.

## A snapshot named seed comes back

A snapshot named `seed` loads automatically on the next `ddev start` of a project with the same name and an empty database. After a delete, recreating that project brings the seed data back. Tell the person before they delete, and name the snapshot to remove if they want a clean start.

Do not rely on the snapshot `ddev delete` takes itself: a global `omit_snapshot_on_delete` setting turns it off. The script takes an explicit snapshot instead.
