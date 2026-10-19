---
name: backend-setup
description: Use when the person wants a new local Drupal backend for their app. It clones the backend template into a new folder, starts it with DDEV, which installs Drupal, writes the project's AGENTS.md rules and installs the pinned Drupal agent skills. Also use it when that site's install fails or the person asks to reset it.
---

# Backend setup

This skill gives the person a local Drupal site, built from the backend template, that their app can use as its backend.

## Before you start

1. Run the machine-check skill first: `bash scripts/check-machine.sh` in that skill. Go on only when its JSON says `ready` is true. Otherwise, show the person what it reports and stop.
2. Agree the project folder with the person. It must not exist yet, or must be empty, and it must be outside this skill's folder. Pass an absolute path; a relative one is resolved from the folder you run the script in. Its parent folder must already exist.
3. The DDEV project name is the folder name. A folder named like an existing DDEV project fails at `ddev start`. Run `ddev list` and pick a name that is not there.

## Set up the site

Run this skill's script:

```bash
bash <this-skill-folder>/scripts/setup-backend.sh [--source <git URL or path>] [--ref <tag, branch or commit>] <project-folder>
```

- `--source` is the template's git URL or a local path. The default source is a placeholder until the template is published, so pass `--source` until then.
- `--ref` is a template tag, branch or commit. The default is the pinned template commit. `--help` prints both defaults.

The script does these steps in order:

1. It clones the template at the requested ref into the folder. The project then sits on a local branch `main` that tracks nothing, and the template's remote is named `template`. The person can add their own `origin`.
2. It runs `ddev start`. The template's start hook installs Drupal, so this step takes about a minute.
3. It checks that the login page, `/user/login`, answers 200. The template may close the front page to visitors, so the script does not check it.
4. It writes the vibe-config-drupal rules block into the project's `AGENTS.md` (`scripts/write-agents-block.sh`).
5. It installs the pinned `drupal-ddev` and `drupal-config-mgmt` skills into the project's `.claude/skills/` (`scripts/install-drupal-skills.sh`).
6. It prints a `Site URL:` line and a `Login link:` line. Give both to the person.

The admin password is random. To log in later, run `ddev drush user:login` in the project folder.

Running the script again on a folder it set up skips the clone and refreshes `AGENTS.md`. A new `AGENTS.md` is an uncommitted change in the project's git. Offer to commit it.

The One Line Installer is an optional helper for getting DDEV. This skill does not need it.

## Messages from the template

Watch the `ddev start` output for these two lines.

**Security advisories.** When the output holds this line, show it to the person:

```
WARNING: composer audit reported security advisories or abandoned packages; run composer audit
```

Offer to run `ddev composer update`. Run it only when the person agrees.

**Half-finished install.** When the output holds this line, the database has tables but Drupal did not finish installing:

```
ERROR: the database has tables but the Drupal install did not finish. Recover with: ddev drush sql:drop -y && ddev restart
```

Recover in the project folder with:

```bash
ddev drush sql:drop -y && ddev restart
```

The restart runs the start hook again, and it installs Drupal on the empty database. Then run the setup script again on the same folder. It skips the clone and writes `AGENTS.md`, installs the skills and prints the login link.

## The three resets

When the person asks to reset, find out which of these they mean.

1. **Undo** a recent change: `ddev snapshot restore --latest`. It restores the latest snapshot.
2. **Fresh install**, on sites made from this template only. Warn the person first that all content and configuration in the database is lost. When they agree, run `ddev snapshot` first, then `ddev drush sql:drop -y && ddev restart`. The restart installs Drupal again.
3. **Delete the project**: send this to the safe-delete skill. Only the person deletes a project. Never run DDEV's delete command yourself, and never remove the project folder yourself.

## When a step fails

After you fix the cause, run the setup script again on the same folder. It skips the clone and finishes the steps it missed.

The script stops with a message and leaves the folder and the DDEV project as they are.

- `ddev` is missing: run the machine-check skill and follow what it says.
- The folder exists and is not empty: pick another folder, or ask the person.
- `ddev start` fails: show the person the output. A name clash with another DDEV project is a common cause. See "Before you start".
- The login page does not answer 200: show the person the status and the `ddev start` output.
