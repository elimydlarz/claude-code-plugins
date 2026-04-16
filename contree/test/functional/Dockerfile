FROM node:22-slim

RUN apt-get update && apt-get install -y git jq procps && rm -rf /var/lib/apt/lists/*
RUN npm install -g @anthropic-ai/claude-code

RUN useradd -m -s /bin/bash testuser

# Fixtures are added via build context (built from contree/test/)
COPY --chown=testuser:testuser fixtures/ /fixtures/
RUN for dir in /fixtures/*/; do \
      [ -f "$dir/package.json" ] && (cd "$dir" && npm install --silent 2>/dev/null) || true; \
    done

WORKDIR /work
RUN chown testuser:testuser /work
USER testuser
