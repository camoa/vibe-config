import { Suspense } from "react";
import { redirect } from "next/navigation";
import { connection } from "next/server";
import { getSession } from "@/lib/session";
import { isSignedIn } from "@/lib/auth-state";
import { fetchArticles, backendIsUp } from "@/lib/drupal";

const Down = () => (
  <p>
    The Drupal backend is not running. Start it with <code>ddev start</code> in
    the backend folder, then reload.
  </p>
);

async function Home({ searchParams }: { searchParams: Promise<{ backend?: string }> }) {
  const forcedDown = (await searchParams).backend === "down";
  // The session read checks expiry against the clock, so render per request.
  await connection();
  const session = await getSession();

  if (!isSignedIn(session)) {
    if (forcedDown || !(await backendIsUp())) return <Down />;
    return <a href="/api/auth/login">Sign in</a>;
  }
  if (forcedDown) return <Down />;
  if (session.expiresAt && session.expiresAt <= Date.now()) {
    redirect("/api/auth/refresh?next=/");
  }

  const result = await fetchArticles(session.accessToken!);
  return (
    <>
      <p>Signed in as {session.userName}</p>
      <form action="/api/auth/logout" method="post">
        <button type="submit">Log out</button>
      </form>
      {result.kind === "down" && <Down />}
      {result.kind === "error" && (
        <p>Drupal answered with an error (status {result.status}).</p>
      )}
      {result.kind === "ok" && (
        <ul>
          {result.articles.map((a) => (
            <li key={a.id}>{a.title}</li>
          ))}
        </ul>
      )}
    </>
  );
}

export default function Page(props: { searchParams: Promise<{ backend?: string }> }) {
  return (
    <main>
      <Suspense fallback={<p>Loading</p>}>
        <Home searchParams={props.searchParams} />
      </Suspense>
    </main>
  );
}
