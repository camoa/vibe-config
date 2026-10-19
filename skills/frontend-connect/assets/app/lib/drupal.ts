const base = () => process.env.DRUPAL_BASE_URL!.replace(/\/$/, "");

export type ArticlesResult =
  | { kind: "ok"; articles: { id: string; title: string }[] }
  | { kind: "down" }
  | { kind: "error"; status: number };

// After ddev stop the DDEV router still answers, with no JSON body.
const isJson = (res: Response) =>
  (res.headers.get("content-type") ?? "").includes("json");

export async function fetchArticles(accessToken: string): Promise<ArticlesResult> {
  try {
    const res = await fetch(
      `${base()}/jsonapi/node/article?sort=-created&fields[node--article]=title`,
      {
        headers: { Authorization: `Bearer ${accessToken}` },
        cache: "no-store",
      },
    );
    if (!isJson(res)) return { kind: "down" };
    if (!res.ok) return { kind: "error", status: res.status };
    const body = await res.json();
    return {
      kind: "ok",
      articles: body.data.map((n: { id: string; attributes: { title: string } }) => ({
        id: n.id,
        title: n.attributes.title,
      })),
    };
  } catch {
    return { kind: "down" };
  }
}

export async function backendIsUp(): Promise<boolean> {
  try {
    return isJson(await fetch(`${base()}/jsonapi`, { cache: "no-store" }));
  } catch {
    return false;
  }
}
