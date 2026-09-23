import { Container, getContainer } from "@cloudflare/containers";

export class GoogleAnalyticsMCP extends Container {
  defaultPort = 8080;
  sleepAfter = "5m";

  constructor(ctx, env) {
    super(ctx, env);
    // Use this.envVars in constructor -- getEnv() does NOT exist in @cloudflare/containers
    this.envVars = {
      GOOGLE_CLIENT_ID: env.GOOGLE_CLIENT_ID || "",
      GOOGLE_CLIENT_SECRET: env.GOOGLE_CLIENT_SECRET || "",
      GOOGLE_REFRESH_TOKEN: env.GOOGLE_REFRESH_TOKEN || "",
      GOOGLE_ANALYTICS_PROPERTY_ID: env.GOOGLE_ANALYTICS_PROPERTY_ID || "",
    };
  }
}

export default {
  async fetch(request, env) {
    const apiToken = request.headers.get("X-API-Token") || "";
    const cfEmail = request.headers.get("CF-Access-Authenticated-User-Email") || "";
    // CF Access injects Jwt-Assertion for ALL authenticated requests:
    //   - Web SSO users: have both cfEmail (@fundingsocieties.com) AND cfJwt
    //   - Service tokens (MCP Portal): have cfJwt but NO email
    // Cloudflare strips incoming CF-Access-* headers so these cannot be spoofed
    const cfJwt = request.headers.get("CF-Access-Jwt-Assertion") || "";

    // Auth Method 1: CF Access (custom domain) — service tokens or web SSO
    const hasAccessAuth = cfEmail.endsWith("@fundingsocieties.com") || cfJwt.length > 0;
    // Auth Method 2: DEV_API_TOKEN — workers.dev URL for MCP Inspector / curl / CI
    // Accept via header OR ?token= query param (Inspector can't always set headers)
    const url = new URL(request.url);
    const queryToken = url.searchParams.get("token") || "";
    const hasDevToken = env.DEV_API_TOKEN && (apiToken === env.DEV_API_TOKEN || queryToken === env.DEV_API_TOKEN);

    if (!hasAccessAuth && !hasDevToken) {
      return new Response(
        JSON.stringify({ error: "forbidden", hint: "Use CF-Access headers or X-API-Token/token query param" }),
        { status: 403, headers: { "content-type": "application/json" } }
      );
    }

    // Strip token from query string before forwarding to container
    if (url.searchParams.has("token")) {
      url.searchParams.delete("token");
      request = new Request(url.toString(), request);
    }

    const container = getContainer(env.GOOGLE_ANALYTICS_MCP, "v2");
    return container.fetch(request);
  }
};
