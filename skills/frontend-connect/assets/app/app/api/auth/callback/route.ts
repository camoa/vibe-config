import { NextResponse } from "next/server";
import * as client from "openid-client";
import { getOAuthConfig, appUrl } from "@/lib/oauth";
import { getSession } from "@/lib/session";

export async function GET(request: Request) {
  const { search } = new URL(request.url);
  const session = await getSession();
  const { oauthState, codeVerifier } = session;
  delete session.oauthState;
  delete session.codeVerifier;
  if (!oauthState || new URLSearchParams(search).get("state") !== oauthState) {
    await session.save();
    return NextResponse.redirect(appUrl("/"));
  }
  try {
    const config = getOAuthConfig();
    const tokens = await client.authorizationCodeGrant(
      config,
      appUrl(`/api/auth/callback${search}`),
      { pkceCodeVerifier: codeVerifier, expectedState: oauthState },
    );
    const info = await client.fetchUserInfo(
      config,
      tokens.access_token,
      client.skipSubjectCheck,
    );
    session.accessToken = tokens.access_token;
    session.refreshToken = tokens.refresh_token;
    session.expiresAt = Date.now() + (tokens.expires_in ?? 0) * 1000;
    session.userName = String(info.name ?? info.preferred_username ?? info.sub);
    await session.save();
    return NextResponse.redirect(appUrl("/"));
  } catch {
    return NextResponse.redirect(appUrl("/?backend=down"));
  }
}
