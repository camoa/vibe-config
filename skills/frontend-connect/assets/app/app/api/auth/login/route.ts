import { NextResponse } from "next/server";
import * as client from "openid-client";
import { getOAuthConfig, appUrl } from "@/lib/oauth";
import { getSession } from "@/lib/session";

export async function GET() {
  try {
    const res = await fetch(process.env.DRUPAL_BASE_URL!, { method: "HEAD" });
    if (res.status >= 500 || res.status === 404) throw new Error("down");
  } catch {
    return NextResponse.redirect(appUrl("/?backend=down"));
  }
  const codeVerifier = client.randomPKCECodeVerifier();
  const state = client.randomState();
  const session = await getSession();
  session.codeVerifier = codeVerifier;
  session.oauthState = state;
  await session.save();
  const url = client.buildAuthorizationUrl(getOAuthConfig(), {
    redirect_uri: appUrl("/api/auth/callback").href,
    scope: process.env.DRUPAL_SCOPE!,
    code_challenge: await client.calculatePKCECodeChallenge(codeVerifier),
    code_challenge_method: "S256",
    state,
  });
  return NextResponse.redirect(url);
}
