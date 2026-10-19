# vibe-config-drupal

Agent skills that set up Drupal as the backend of a Next.js app, in the slot Supabase usually fills.
They are for people who build with an AI coding agent and do not know Drupal: the agent does the
Drupal work as configuration and contributed modules, not custom code.

## Install

Run this from your project folder:

```bash
npx skills add camoa/vibe-config-drupal
```

The [skills CLI](https://github.com/vercel-labs/skills) asks which skills to install and for which
agents. It works with Claude Code, Codex, Cursor and many other agents.

To pick one skill and one agent:

```bash
npx skills add camoa/vibe-config-drupal --skill machine-check -a codex
```

To list the skills without installing them, add `--list`. The CLI itself needs Node.js 22.20 or
later.

## What you need

- Docker, or another container runtime DDEV supports, such as OrbStack or Colima.
- [DDEV](https://ddev.com), which runs the local Drupal site, and `mkcert`, which DDEV's install
  sets up.
- Node.js 22.20 or later and npm, for the skills CLI and the Next.js app.

The machine-check skill checks these and tells you what is missing.

## Skills

| Skill | What it is for |
|---|---|
| `machine-check` | Checks that this computer can run a local Drupal site, and lists what to install. |
| `backend-setup` | Creates a local Drupal backend from the backend template and starts it with DDEV. |
| `frontend-connect` | Creates a Next.js app that signs in against that backend. |
| `safe-delete` | Picks the mildest reset, and hands you the command to delete a project yourself. |

backend-setup clones the backend template,
[camoa/vibe-config-drupal-backend](https://github.com/camoa/vibe-config-drupal-backend), at the tag
`v0.1.0`. It also installs two skills from
[grasmash/drupal-claude-skills](https://github.com/grasmash/drupal-claude-skills) (MIT),
`drupal-ddev` and `drupal-config-mgmt`, at a pinned commit into your backend project's
`.claude/skills/` folder, with their licence. This repository does not include them.

## Usage

Things to say to your agent, in the order a newcomer would go:

1. "Check whether my computer is ready to run a local Drupal site."
2. "Set up a Drupal backend for my app in a new folder called `my-app-backend`."
3. "Create a Next.js app with login, connected to that backend."
4. "Delete the test project `my-app-backend`."

The agent never deletes a project itself. safe-delete gives you a command to run in your own
terminal, which asks you to type the project name.

## Limits

- Local only. The skills set up a DDEV site on your computer. There is no hosting or deploy step
  yet.
- macOS is untested. On Windows, the skills need WSL2.
- The login refresh is safe within one server process, which is what `npm run dev` and a single
  `next start` run. Several server processes behind one app can sign a person out when they refresh
  at the same time.
- After logout, a token already issued stays valid for up to 300 seconds, because Drupal's OAuth
  module has no revoke endpoint.
- Drupal does not match Supabase everywhere. It has no realtime subscriptions without code and an
  extra service. Access rules by configuration cover owner and role rules on content; team or
  sharing rules over the API need code. There is no table editor or SQL console like Supabase
  Studio, and no free hosted production tier.

## Licence

This repository is MIT licensed; see [LICENSE](LICENSE). The backend template it clones,
camoa/vibe-config-drupal-backend, is GPL-2.0-or-later.
