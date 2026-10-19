---
name: frontend-connect
description: Use when the person wants a Next.js app that signs in against their local Drupal backend. It creates the app with create-next-app, lays the skill's app files over it, pins the login packages and writes the .env.local file. Also use it to lay the skill's app files over an app it already made, or when that script fails.
---

# Frontend connect

This skill gives the person a Next.js app wired to their Drupal backend for sign-in. The backend is a site made by the backend-setup skill.

## Before you start

1. Run the machine-check skill first: `bash scripts/check-machine.sh` in that skill. Go on only when its JSON says `ready` is true. Otherwise, show the person what it reports and stop.
2. Node 22.13 or later and `mkcert` must be installed. The script checks both.
3. The backend must be running, and it must carry the template's oauth-login work: the Simple OAuth client `nextjs` with redirect URI `http://localhost:3000/api/auth/callback`. A backend made from the template's main before that work lands has no such client. Until then, make the backend with backend-setup and `--ref feature/oauth-login`.
4. Propose an app folder beside the backend folder, for example `<backend-folder>-app`. It must not exist yet, or must be empty. Tell the person the path and wait for their agreement before you run the script.

## Create the app

Run this skill's script with absolute paths:

```bash
bash <this-skill-folder>/scripts/setup-frontend.sh --backend <backend-project-folder> <app-folder>
```

The script does these steps in order:

1. It checks Node, npm, mkcert and that the backend answers.
2. It runs `create-next-app@16.4.1` with explicit flags (TypeScript, App Router, ESLint, Tailwind, no `src/`, npm). Next.js 16.4.1 is the security floor.
3. It copies this skill's `assets/app` folder over the new app.
4. It installs `openid-client` and `iron-session` at exact versions.
5. It sets the `dev` script so `npm run dev` exports `NODE_EXTRA_CA_CERTS` from `mkcert -CAROOT` before `next dev`. Node rejects DDEV's mkcert certificate without it and reads the variable only at launch. npm runs scripts through `sh`, so this does not work under plain Windows cmd.
6. It writes `.env.local` once, with `DRUPAL_BASE_URL`, `DRUPAL_CLIENT_ID`, `DRUPAL_SCOPE`, `APP_URL` and a random `SESSION_SECRET`.
7. It stops unless git confirms `.env.local` is ignored.
8. It prints `App folder:`, `Backend URL:` and the start command. Give them to the person.

No Drupal host sits in the app's source. To point the app at another backend, edit `DRUPAL_BASE_URL` in `.env.local` only.

Running the script again on an app it made skips create-next-app and the install, copies the app files over the app again, and never touches `.env.local`.

## Sign-in and logout

Sign-in uses Drupal's own login form. Logout drops the tokens from the app's session and then sends the person to Drupal's logout page, which asks for one confirm click. That ends the Drupal login.

Simple OAuth has no revoke endpoint, so a token already issued stays valid for up to 300 seconds after logout, and a refresh token until its lifetime ends. Tell the person this if they ask how final a logout is.

## When a step fails

After you fix the cause, run the script again on the same folder.

- Node is older than 22.13: install a newer Node through the machine-check skill's advice.
- The backend did not answer: run `ddev start` in the backend folder.
- The folder exists and is not empty: pick another folder, or ask the person.
- `create-next-app` or `npm install` fails: show the person the output. A partly made app folder is not a valid rerun target until `package.json` lists `openid-client`; remove it with the person's agreement and run again.
- `.env.local` is not ignored by git: add `.env.local` to the app's `.gitignore`, then run again.
