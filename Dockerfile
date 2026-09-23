FROM fundingsocietiesdocker/python:3.11-latest

USER root

# Set working directory
WORKDIR /app

# Create a non-root user and set proper permissions
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

# Copy and install dependencies as root first
COPY pyproject.toml .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -e .

# Copy source code (CORRECT: analytics_mcp, not ads_mcp)
COPY analytics_mcp/ ./analytics_mcp/
COPY run_server.py .

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    chown appuser:appuser /entrypoint.sh

# Switch to non-root user
USER appuser

EXPOSE 8080


CMD ["/entrypoint.sh"]
