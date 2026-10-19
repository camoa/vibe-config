import type { SessionData } from "@/lib/session";

// Signed in means the session holds an access token, never just a name.
export const isSignedIn = (session: SessionData) => Boolean(session.accessToken);
