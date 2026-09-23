# Google Analytics MCP - Cloudflare Deployment Guide

## Overview

Deploy the Google Analytics MCP server to Cloudflare Containers with authentication via:
- **Cloudflare Access** (custom domain) - for MCP Portal and web SSO users
- **DEV_API_TOKEN** (workers.dev URL) - for local testing with MCP Inspector

## Prerequisites

✅ **Completed:**
- [x] Local testing successful
- [x] Docker image builds and runs
- [x] MCP Inspector connection verified
- [x] OAuth credentials obtained from Google Cloud Console

📋 **Required:**
- Cloudflare account with Workers paid plan
- Wrangler CLI installed: `npm install -g wrangler`
- Domain configured in Cloudflare (e.g., `fundingasiagroup.com`)

## Step 1: Install Wrangler and Login

```bash
# Install Wrangler CLI
npm install -g wrangler

# Login to Cloudflare
wrangler login

# Verify account
wrangler whoami
```

## Step 2: Configure Secrets

Set the required secrets in Cloudflare:

```bash
cd ~/code/AI-Workers/google-analytics-mcp

# Set OAuth credentials (from Google Cloud Console)
wrangler secret put GOOGLE_CLIENT_ID
wrangler secret put GOOGLE_CLIENT_SECRET
wrangler secret put GOOGLE_REFRESH_TOKEN

# Set Google Analytics Property ID
wrangler secret put GOOGLE_ANALYTICS_PROPERTY_ID

# Set DEV_API_TOKEN for local testing (generate a random token)
# Example: openssl rand -hex 32
wrangler secret put DEV_API_TOKEN
```

**Secret Values:**

| Secret | Source | Example |
|--------|--------|---------|
| `GOOGLE_CLIENT_ID` | OAuth 2.0 Client ID from Google Cloud Console | `123456789.apps.googleusercontent.com` |
| `GOOGLE_CLIENT_SECRET` | OAuth 2.0 Client Secret | `GOCSPX-xxx...` |
| `GOOGLE_REFRESH_TOKEN` | OAuth refresh token from `adc_credentials.json` | `1//xxx...` |
| `GOOGLE_ANALYTICS_PROPERTY_ID` | GA4 Property ID from Admin > Property Settings | `555359509` |
| `DEV_API_TOKEN` | Random token for dev access | Generate with `openssl rand -hex 32` |

## Step 3: Deploy to Cloudflare

```bash
cd ~/code/AI-Workers/google-analytics-mcp

# Deploy the worker and container
wrangler deploy

# Expected output:
# ✓ Built successfully
# ✓ Container image uploaded
# ✓ Published mcp_google-analytics_fsmk-pm
#   https://mcp-google-analytics-fsmk-pm.<account>.workers.dev
```

## Step 4: Test Deployment

### Test with DEV_API_TOKEN (workers.dev URL)

```bash
# Get your workers.dev URL from deployment output
WORKER_URL="https://mcp-google-analytics-fsmk-pm.<account>.workers.dev"

# Generate a test token (should match the one you set in secrets)
DEV_TOKEN="your-dev-token-here"

# Test with curl
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "X-API-Token: $DEV_TOKEN" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' \
  "$WORKER_URL/mcp"
```

### Test with MCP Inspector

1. Open MCP Inspector: `npx @modelcontextprotocol/inspector@latest`
2. Add server:
   - Name: `google-analytics-cloudflare`
   - Transport: `Streamable HTTP`
   - URL: `https://mcp-google-analytics-fsmk-pm.<account>.workers.dev/mcp?token=YOUR_DEV_TOKEN`
3. Toggle connection ON
4. Verify tools are available

## Step 5: Configure Custom Domain (Production)

### 5.1: Update wrangler.json

The `wrangler.json` already has the custom domain configured:
```json
"routes": [
  {
    "pattern": "mcp-google-analytics-fsmk-pm.fundingasiagroup.com",
    "custom_domain": true
  }
]
```

### 5.2: Deploy with Custom Domain

```bash
wrangler deploy
```

### 5.3: Configure Cloudflare Access

1. Go to Cloudflare Dashboard → Zero Trust → Access → Applications
2. Create Application:
   - **Name:** `Google Analytics MCP`
   - **Subdomain:** `mcp-google-analytics-fsmk-pm`
   - **Domain:** `fundingasiagroup.com`
   - **Path:** Leave empty (protect entire domain)
3. Add Policies:
   - **Policy 1 - MCP Portal Service Token:**
     - Action: Allow
     - Include: Service Auth → Select your MCP Portal service token
   - **Policy 2 - Web SSO Users:**
     - Action: Allow
     - Include: Emails ending in `@fundingsocieties.com`

### 5.4: Test Custom Domain

```bash
# Test with service token (from MCP Portal)
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "CF-Access-Client-Id: <service-token-id>" \
  -H "CF-Access-Client-Secret: <service-token-secret>" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' \
  "https://mcp-google-analytics-fsmk-pm.fundingasiagroup.com/mcp"
```

## Step 6: Add to MCP Portal

1. Go to MCP Portal: `https://mcp-portal.fundingasiagroup.com`
2. Navigate to **Servers** section
3. Click **Add Server**
4. Configure:
   - **Name:** `Google Analytics MCP`
   - **Description:** `Query Google Analytics 4 (GA4) data - reports, metrics, conversions, funnels`
   - **Transport:** `Streamable HTTP`
   - **URL:** `https://mcp-google-analytics-fsmk-pm.fundingasiagroup.com/mcp`
   - **Authentication:** Service Token (configured in Step 5.3)
5. Test connection
6. Save

## Architecture

```
User/Claude → MCP Portal → CF Access → Worker → Container → GA4 API
                             ↓
                        Service Token
                             ↓
                    Authentication Check
```

## Security Features

✅ **Authentication:**
- Cloudflare Access with service tokens (production)
- DEV_API_TOKEN for local testing (dev only)
- No public access without valid credentials

✅ **Secrets Management:**
- All credentials stored in Cloudflare secrets
- Never exposed in logs or responses
- Encrypted at rest and in transit

✅ **Network Security:**
- DNS rebinding protection disabled (required for MCP)
- Custom domain with HTTPS
- Service token rotation support

## Monitoring and Logs

### View Real-time Logs

```bash
# Tail worker logs
wrangler tail

# View container logs
wrangler tail --format json | jq 'select(.event.request)'
```

### Check Deployment Status

```bash
# List deployments
wrangler deployments list

# View current deployment
wrangler deployments view
```

## Troubleshooting

### Error: "forbidden"

**Cause:** Missing or invalid authentication

**Fix:**
1. Verify DEV_API_TOKEN is set: `wrangler secret list`
2. Check token matches in request: `X-API-Token` header or `?token=` query param
3. For custom domain: verify CF Access is configured

### Error: "Container failed to start"

**Cause:** Missing secrets or invalid credentials

**Fix:**
1. Verify all secrets are set: `wrangler secret list`
2. Check container logs: `wrangler tail`
3. Test locally first: `docker run ...`

### Error: "Cannot find session"

**Cause:** Container restarted or session expired

**Fix:**
- This is normal - client will automatically reconnect
- Check `sleepAfter = "5m"` in worker.js (containers sleep after 5 minutes of inactivity)

## Cost Estimation

**Cloudflare Workers:**
- Workers Paid Plan: $5/month
- Container compute: ~$0.50/million requests
- Storage: Minimal (< $0.01/month)

**Expected Monthly Cost:**
- Base: $5/month (Workers plan)
- Usage: < $1/month (typical usage)
- **Total: ~$6/month**

## Next Steps

After deployment:
1. Add server to MCP Portal
2. Test with Claude Desktop or Cowork
3. Monitor usage and performance
4. Set up alerting for errors

## Reference Files

- `worker.js` - Cloudflare Worker wrapper with authentication
- `wrangler.json` - Cloudflare deployment configuration
- `Dockerfile` - Container image definition
- `run_server.py` - MCP server with streamable-http transport
- `entrypoint.sh` - Container startup script
