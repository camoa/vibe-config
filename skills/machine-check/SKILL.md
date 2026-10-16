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
- `checks.container`: the container runtime, with three keys.
  - `running`: `true` when the runtime answers.
  - `provider`: DDEV's platform name when DDEV did the check, such as `orbstack` or `linux-docker`. Otherwise `orbstack`, `colima`, `docker-desktop` or `unknown`. It is `none` when neither DDEV nor Docker is installed.
  - `via`: how it checked: `ddev-dockercheck`, `docker-info` or `none`.
- `checks.ddev`, `checks.node`, `checks.npm`: each has `installed` (`true` or `false`) and `version` (empty when not installed).
- `next_steps`: an array of objects with `piece`, `step` and `person_runs`. `piece` is `os`, `container`, `ddev`, `node` or `npm`. `step` is the step's text, naming the command to run or the web address to open. When `person_runs` is `true`, ask the person to do the step. Run the check again afterwards.

When `ready` is `true`, go on to the next stage.
