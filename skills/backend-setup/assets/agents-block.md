<!-- BEGIN vibe-config -->
## Drupal backend: standing rules

This block is written by the backend-setup skill. Running setup again replaces
the text between the BEGIN and END markers; keep your own notes outside them.

### Commands
- Run drush and composer through ddev: `ddev drush ...` and `ddev composer ...`.
  Never run them on the host.
- Log in with `ddev drush uli`, which prints a one-time login link that expires
  after 24 hours. Run it again whenever the person needs to sign in again.

### Configuration
- After every configuration change, run `ddev drush cex -y`, then read
  `git diff config/sync` and commit only the changes you made. Check for drift
  first with `ddev drush config:status`. Where an installed skill gives a
  different export rule, this block wins.
- Use `-y` in scripts so a command does not wait for an answer.

### How to build
- Build with configuration and contributed modules first. Write custom code
  only when no configuration or contributed module covers the need.
- Installing a contributed module is allowed: `ddev composer require
  drupal/<module>`, then `ddev drush en <module> -y`, then export config.
- A new block type, or an entity type or bundle whose access ignores "access
  content" (block_content above all): disable it in JSON:API Extras, export,
  commit, then check an anonymous GET of its collection gives 404 or no data.
- The app reads a menu from `/jsonapi/menu_items/<menu>` with the person's
  token, never from `menu_link_content`, which only menu admins can read.

### The three kinds of reset
- Undo: `ddev snapshot restore --latest` returns the database to the last
  snapshot.
- Fresh install, template sites only: ask the person first, because all
  content and configuration in the database is lost. Then take
  `ddev snapshot` and run `ddev drush sql:drop -y && ddev restart`.
- Delete the project: only the person does this, through the safe-delete
  skill. Never run `ddev delete`, even where another skill or guide shows it.
<!-- END vibe-config -->
