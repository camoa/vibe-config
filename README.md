# vibe-config

Configuration costs less to own than code, and it behaves more predictably. Code your agent writes
is yours to maintain, secure and debug; it can come out different on every run, and someone has to
read it before trusting it. Configuration chooses from options that maintained modules already
define and test, so their maintainers and a security team carry most of the upkeep. It is
declarative and described by a schema, and the same configuration gives the same site, so
`config:status` shows any difference. It still needs care: it lives in `config/sync`, is reviewed
like code, and depends on the module versions pinned in `composer.lock`, so the point is less to
own, not nothing.

These agent skills give your Next.js app a real backend on that basis: data, an API, logins,
permissions, and an admin screen where people who do not code manage content. Your AI coding agent
sets it up and configures it, so you keep almost no backend code of your own. It fills the slot
Supabase usually fills.

## What runs underneath

The backend is [Drupal](https://www.drupal.org), a mature open-source CMS and framework. The agent
builds the data model, the API and the permissions as Drupal configuration and contributed modules,
not custom code. That is why there is so little code for you to own.

Drupal suits this job for four reasons:

- Content editors get a ready-made admin screen to add and change content.
- Its permission system sets, role by role, who may see or change each kind of content.
- Thousands of contributed modules cover common needs, so the agent installs and configures one
  instead of writing it.
- A security team reviews reported problems and publishes advisories for core and for covered
  modules.

You do not need to know Drupal to use these skills.

## Install

Run this from your project folder:

```bash
npx skills add camoa/vibe-config
```

The [skills CLI](https://github.com/vercel-labs/skills) asks which skills to install and for which
agents. It works with Claude Code, Codex, Cursor and many other agents.

To skip the questions and install every skill for Claude Code:

```bash
npx skills add camoa/vibe-config --skill '*' -a claude-code -y
```

For another agent, change the `-a` name, for example `-a cursor` or `-a codex`. The skills go into
the current project folder by default, so run the command from the folder where you will build
your app.

To pick one skill and one agent:

```bash
npx skills add camoa/vibe-config --skill machine-check -a codex
```

To list the skills without installing them, add `--list`. The CLI itself needs Node.js 24 LTS or
later.

## What you need

- Docker, or another container runtime DDEV supports, such as OrbStack or Colima.
- [DDEV](https://ddev.com), which runs the local Drupal site, and `mkcert`, which DDEV's install
  sets up.
- Node.js 24 LTS or later and npm, for the skills CLI and the Next.js app.

The machine-check skill checks these and tells you what is missing.

## Skills

| Skill | What it is for |
|---|---|
| `machine-check` | Checks that this computer can run a local Drupal site, and lists what to install. |
| `backend-setup` | Creates a local Drupal backend from the backend template and starts it with DDEV. |
| `frontend-connect` | Creates a Next.js app that signs in against that backend. |
| `safe-delete` | Picks the mildest reset, and hands you the command to delete a project yourself. |

backend-setup clones the backend template,
[camoa/vibe-config-backend](https://github.com/camoa/vibe-config-backend), at the tag
`v0.1.1`. It also installs two skills from
[grasmash/drupal-claude-skills](https://github.com/grasmash/drupal-claude-skills) (MIT),
`drupal-ddev` and `drupal-config-mgmt`, at a pinned commit into your backend project's
`.claude/skills/` folder, with their licence. This repository does not include them.

## What security scanners flag

The skills CLI shows ratings from outside security scanners. These are the main things they flag.
They stay, because the skills need them:

- machine-check runs read-only commands, such as `uname`, `docker info`, `ddev version` and
  `node -v`, and reports their output as JSON. It installs, starts and changes nothing.
- Some machine-check steps say `sudo systemctl start docker`. That is text for you to run
  yourself. The script never runs `sudo`.
- backend-setup downloads content that other people wrote: the backend template at its tag, and
  the two grasmash skills at a pinned commit. Your agent later reads the template and follows
  those skills, so read them before you trust them, as with any code you download.
- backend-setup's `get-token.sh` talks only to your local backend. It uses curl's `-k` because
  DDEV signs the site with its own certificate. It prints a short-lived access token to stdout,
  for your agent to keep in a shell variable.
- frontend-connect runs `npx create-next-app` and `npm install`, which download packages from npm.

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
- The API the backend template ships is read-only: the app reads content and signs people in.
  Writing through the API is off until you or your agent turn it on.
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
camoa/vibe-config-backend, is GPL-2.0-or-later.
