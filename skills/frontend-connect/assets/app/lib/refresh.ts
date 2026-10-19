import * as client from "openid-client";
import { getOAuthConfig } from "@/lib/oauth";

type Tokens = Awaited<ReturnType<typeof client.refreshTokenGrant>>;

// Drupal rotates the refresh token on use, so two requests refreshing with the
// same token would make the second one fail and sign the person out. Requests
// carrying one token share one exchange, and its result stays for 15 seconds for
// requests that arrive with the spent token. This holds within one server
// process, which is what `next dev` and a single `next start` run.
const exchanges = new Map<string, Promise<Tokens>>();

export function refreshOnce(refreshToken: string): Promise<Tokens> {
  let exchange = exchanges.get(refreshToken);
  if (!exchange) {
    exchange = client.refreshTokenGrant(getOAuthConfig(), refreshToken);
    exchanges.set(refreshToken, exchange);
    exchange.then(
      () => setTimeout(() => exchanges.delete(refreshToken), 15_000),
      () => exchanges.delete(refreshToken),
    );
  }
  return exchange;
}
