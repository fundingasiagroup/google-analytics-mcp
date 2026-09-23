#!/usr/bin/env python3
"""Startup script for streamable-http transport on 0.0.0.0:8080"""

import sys
from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings
import analytics_mcp.coordinator as coordinator


# Create FastMCP wrapper around the existing low-level Server
mcp = FastMCP("Google Analytics MCP Server")

# Copy settings
mcp.settings.host = "0.0.0.0"
mcp.settings.port = 8080
mcp.settings.transport_security = TransportSecuritySettings(
    enable_dns_rebinding_protection=False
)

# Wire up the low-level server's handlers to FastMCP
mcp._mcp_server = coordinator.app


if __name__ == "__main__":
    print("Starting Google Analytics MCP server on 0.0.0.0:8080...", file=sys.stderr)
    mcp.run(transport="streamable-http")
