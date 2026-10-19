import { NextResponse } from "next/server";
import * as client from "openid-client";
import { getOAuthConfig, appUrl } from "@/lib/oauth";
import { getSession } from "@/lib/session";

export async function GET(request: Request) {
  const next = new URL(request.url).searchParams.get("next") ?? "/";
  const target =
    appUrl(next).origin === appUrl("/").origin ? next : "/";
  const session = await getSession();
  if (!session.refreshToken) return NextResponse.redirect(appUrl(target));
  try {
    const tokens = await client.refreshTokenGrant(
      getOAuthConfig(),
      session.refreshToken,
    );
    session.accessToken = tokens.access_token;
    if (tokens.refresh_token) session.refreshToken = tokens.refresh_token;
    session.expiresAt = Date.now() + (tokens.expires_in ?? 0) * 1000;
    await session.save();
  } catch (error) {
    if (error instanceof client.ResponseBodyError) {
      session.accessToken = undefined;
      session.refreshToken = undefined;
      session.expiresAt = undefined;
      await session.save();
      return NextResponse.redirect(appUrl(target));
    }
    return NextResponse.redirect(appUrl("/?backend=down"));
  }
  return NextResponse.redirect(appUrl(target));
}
