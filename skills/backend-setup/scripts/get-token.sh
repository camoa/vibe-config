#!/usr/bin/env bash
# Print a signed-in access token for the backend, got the way the app gets one:
# the nextjs client, PKCE and the authenticated scope. It signs in through a
# one-time login link, so no password or secret is stored. Only the token goes
# to stdout. Nothing listens on the redirect URI; the code is read from the
# Location header, which automatic authorization sends at once.
set -euo pipefail

die() { echo "Error: $*" >&2; exit 1; }

client_id='nextjs'
scope='authenticated'
redirect_uri='http://localhost:3000/api/auth/callback'

name=''
if [ "${1:-}" = '--name' ]; then
  [ $# -ge 2 ] || die "--name needs a Drupal user name"
  name="$2"
  shift 2
fi
[ $# -eq 1 ] || die "usage: $(basename "$0") [--name <drupal-user>] <backend-folder>"
[ -d "$1/.ddev" ] || die "$1 is not a DDEV project folder"
command -v openssl >/dev/null || die "openssl is missing"

cd "$1"
if [ -n "$name" ]; then
  uli_out="$(ddev drush uli --name="$name")" || die "ddev drush uli failed"
else
  uli_out="$(ddev drush uli)" || die "ddev drush uli failed"
fi
login_url="$(printf '%s\n' "$uli_out" | grep -E '^https?://' | tail -n 1)"
[ -n "$login_url" ] || die "ddev drush uli printed no login link"
base="${login_url%%/user/reset/*}"

jar="$(mktemp)"
trap 'rm -f "$jar"' EXIT

status="$(curl -sk -c "$jar" -b "$jar" -o /dev/null -w '%{http_code}' "$login_url")"
case "$status" in
  302|303) ;;
  *) die "the login link answered $status, not a redirect; is the user blocked?" ;;
esac

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
verifier="$(openssl rand 48 | b64url)"
challenge="$(printf '%s' "$verifier" | openssl dgst -sha256 -binary | b64url)"
state="$(openssl rand -hex 16)"
redirect_enc='http%3A%2F%2Flocalhost%3A3000%2Fapi%2Fauth%2Fcallback'

location="$(curl -sk -b "$jar" -o /dev/null -w '%{redirect_url}' \
  "$base/oauth/authorize?response_type=code&client_id=$client_id&redirect_uri=$redirect_enc&scope=$scope&code_challenge=$challenge&code_challenge_method=S256&state=$state")"
case "$location" in
  "$redirect_uri"*) ;;
  *) die "authorize did not redirect to the app's callback; it sent: ${location:-no redirect}" ;;
esac
code="$(printf '%s' "$location" | sed -n 's/.*[?&]code=\([^&]*\).*/\1/p')"
[ -n "$code" ] || die "no code in the redirect: $location"

# The code is already URL-encoded in the Location header, so it goes as is.
response="$(curl -sk -X POST "$base/oauth/token" \
  --data "grant_type=authorization_code" \
  --data "client_id=$client_id" \
  --data "redirect_uri=$redirect_enc" \
  --data "code=$code" \
  --data "code_verifier=$verifier")"
token="$(printf '%s' "$response" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')"
[ -n "$token" ] || die "the token endpoint gave no access token: $response"
printf '%s\n' "$token"
