import { NextResponse } from "next/server";
import * as client from "openid-client";
import { appUrl } from "@/lib/oauth";
import { refreshOnce } from "@/lib/refresh";
import { getSession } from "@/lib/session";

export async function GET(request: Request) {
  const next = new URL(request.url).searchParams.get("next") ?? "/";
  let target = "/";
  try {
    if (appUrl(next).origin === appUrl("/").origin) target = next;
  } catch {}
  const session = await getSession();
  if (!session.refreshToken) return NextResponse.redirect(appUrl(target));
  try {
    const tokens = await refreshOnce(session.refreshToken);
    session.accessToken = tokens.access_token;
    if (tokens.refresh_token) session.refreshToken = tokens.refresh_token;
    session.expiresAt = Date.now() + (tokens.expires_in ?? 0) * 1000;
    await session.save();
  } catch (error) {
    if (error instanceof client.ResponseBodyError) {
      session.destroy();
      return NextResponse.redirect(appUrl(target));
    }
    return NextResponse.redirect(appUrl("/?backend=down"));
  }
  return NextResponse.redirect(appUrl(target));
}
