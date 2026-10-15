---
name: machine-check
description: Checks whether this computer is ready to run a local Drupal site (operating system, container runtime, DDEV, Node.js, npm) and lists what the person still has to install. Use before setting up a site, or when a setup step fails because a tool is missing.
---

# Machine check

## When to run it

Run it once before you set up a local site, and again after the person installs something.

## How to run it

From this skill folder:

```sh
bash scripts/check-machine.sh
```

It prints one JSON object and exits 0 whenever the check ran, whatever it found.
`bash scripts/check-machine.sh --summary` prints a short plain-text summary instead.
Show the summary to the person. Read the JSON yourself.

## How to read the JSON

- `os`: `macos`, `wsl2`, `linux` or `unsupported`.
- `ready`: `true` when the container runtime runs, DDEV is installed, and Node.js and npm are installed.
- `checks`: one object per piece, with `installed` and, for the container runtime, `running`.
- `next_steps`: an array of objects with `piece`, `step` and `person_runs`. When `person_runs` is `true`, ask the person to do the step. Run the check again afterwards.

When `ready` is `true`, go on to the next stage.
