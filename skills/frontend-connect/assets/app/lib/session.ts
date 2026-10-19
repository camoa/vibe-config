import { cookies } from "next/headers";
import { getIronSession, type IronSession } from "iron-session";

export interface SessionData {
  accessToken?: string;
  refreshToken?: string;
  expiresAt?: number;
  userName?: string;
  // Held only between /api/auth/login and /api/auth/callback.
  oauthState?: string;
  codeVerifier?: string;
}

export async function getSession(): Promise<IronSession<SessionData>> {
  return getIronSession<SessionData>(await cookies(), {
    password: process.env.SESSION_SECRET!,
    cookieName: "session",
    // Two tokens fill most of one 4096-byte cookie; split rather than fail sign-in.
    chunk: true,
    cookieOptions: {
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.APP_URL!.startsWith("https://"),
    },
  });
}
