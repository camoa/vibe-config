import * as client from "openid-client";

export function getOAuthConfig(): client.Configuration {
  const base = process.env.DRUPAL_BASE_URL!.replace(/\/$/, "");
  const config = new client.Configuration(
    {
      issuer: base,
      authorization_endpoint: `${base}/oauth/authorize`,
      token_endpoint: `${base}/oauth/token`,
      userinfo_endpoint: `${base}/oauth/userinfo`,
    },
    process.env.DRUPAL_CLIENT_ID!,
    undefined,
    client.None(),
  );
  if (base.startsWith("http://")) client.allowInsecureRequests(config);
  return config;
}

export const appUrl = (path: string) => new URL(path, process.env.APP_URL!);
