#!/bin/bash
set -e

# Check if GOOGLE_APPLICATION_CREDENTIALS is already set and the file exists
if [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    echo "Using existing ADC credentials file: $GOOGLE_APPLICATION_CREDENTIALS"
else
    # If not, build ADC JSON from individual env vars (Cloudflare deployment)
    if [ -n "$GOOGLE_CLIENT_ID" ] && [ -n "$GOOGLE_CLIENT_SECRET" ] && [ -n "$GOOGLE_REFRESH_TOKEN" ]; then
        echo "Building ADC credentials from environment variables"
        mkdir -p /app/credentials
        cat > /app/credentials/adc.json << ADCEOF
{
  "client_id": "${GOOGLE_CLIENT_ID}",
  "client_secret": "${GOOGLE_CLIENT_SECRET}",
  "refresh_token": "${GOOGLE_REFRESH_TOKEN}",
  "type": "authorized_user"
}
ADCEOF
        export GOOGLE_APPLICATION_CREDENTIALS="/app/credentials/adc.json"
    else
        echo "Warning: No credentials found. Set GOOGLE_APPLICATION_CREDENTIALS or provide GOOGLE_CLIENT_ID/CLIENT_SECRET/REFRESH_TOKEN"
    fi
fi

# Verify credentials file exists
if [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    echo "✓ Credentials file found: $GOOGLE_APPLICATION_CREDENTIALS"
else
    echo "⚠ Warning: Credentials file not found. Authentication may fail."
fi

# Set Google Analytics Property ID (optional, can be set at tool call time)
if [ -n "$GOOGLE_ANALYTICS_PROPERTY_ID" ]; then
    echo "✓ Using Property ID: $GOOGLE_ANALYTICS_PROPERTY_ID"
    export GOOGLE_ANALYTICS_PROPERTY_ID="${GOOGLE_ANALYTICS_PROPERTY_ID}"
fi

# Start the MCP server
echo "Starting Google Analytics MCP Server..."
exec python run_server.py
