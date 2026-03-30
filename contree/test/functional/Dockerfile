FROM node:22-slim

RUN apt-get update && apt-get install -y git jq && rm -rf /var/lib/apt/lists/*
RUN npm install -g @anthropic-ai/claude-code

RUN useradd -m -s /bin/bash testuser

# Pre-install fixture dependencies so test runs skip npm install
COPY fixtures/ /fixtures/
RUN for dir in /fixtures/*/; do \
      [ -f "$dir/package.json" ] && (cd "$dir" && npm install --silent 2>/dev/null) || true; \
    done && chown -R testuser:testuser /fixtures

WORKDIR /work
RUN chown testuser:testuser /work
USER testuser
