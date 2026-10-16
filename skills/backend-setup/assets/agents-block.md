<!-- BEGIN vibe-config-drupal -->
## Drupal backend: standing rules

This block is written by the backend-setup skill. Running setup again replaces
the text between the BEGIN and END markers; keep your own notes outside them.

### Commands
- Run drush and composer through ddev: `ddev drush ...` and `ddev composer ...`.
  Never run them on the host.
- Log in with `ddev drush user:login`, which prints a one-time login link.

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

### The three kinds of reset
- Undo: `ddev snapshot restore --latest` returns the database to the last
  snapshot.
- Fresh install: take `ddev snapshot` first, then run
  `ddev drush sql:drop -y && ddev restart`.
- Delete the project: only the person does this, through the safe-delete
  skill. Never run `ddev delete`, even where another skill or guide shows it.
<!-- END vibe-config-drupal -->
