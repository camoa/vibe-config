---
name: safe-delete
description: Use when the person asks to reset, wipe, start over or delete a DDEV Drupal site. Picks the right kind of reset, runs only the safe one, and hands the person the exact command for the destructive one.
---

# Safe delete

There are three kinds of reset. Pick the mildest one that does the job.

1. **Undo recent changes.** Run `ddev snapshot restore --latest`, or `ddev snapshot restore <name>` for a named snapshot. The agent may run this itself.
2. **A fresh install that keeps config.** Use the `backend-setup` skill. Do this only on a site made from the vibe-config-drupal-backend template, and only after a snapshot. Tell the person that content will be lost. This skill carries no fresh-install command of its own. Never delete the project to get a fresh install.
3. **Delete the DDEV project.** This is only the person's, through the delete script in `scripts/safe-delete.sh`.

On any other site, offer only the restore and the delete.

## What a snapshot covers

A snapshot covers the database only. It does not cover `sites/default/files`, code or exported config. Say so before the person relies on one.

## Hard rules

- The agent never runs `ddev delete` and never runs the script itself.
- The agent never fakes a terminal (a pseudo-terminal, `script`, piped input) to get past the script's confirmation. The script refuses without a real terminal on purpose.
- The agent hands the person the exact command to run in their own terminal:

```
skills/safe-delete/scripts/safe-delete.sh [--no-snapshot] [--remove-folder PATH] PROJECT
```

The script prints what it will delete, asks the person to type the project name, takes a snapshot, then deletes. Exit 0 means deleted. Exit 2 means a usage error, no terminal, a wrong name or a refused folder. Exit 1 means a ddev call failed.

## Warning: a snapshot named seed comes back

A snapshot named `seed` reloads on the next start of a project with the same name. After a delete and a restart under that name, the seed data returns instead of an empty or fresh site. On a restart with an empty database, a snapshot named `seed` loads instead of a fresh install. Tell the person before they delete.
