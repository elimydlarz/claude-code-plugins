FROM node:22-slim

RUN apt-get update && apt-get install -y git jq && rm -rf /var/lib/apt/lists/*
RUN npm install -g @anthropic-ai/claude-code

RUN useradd -m -s /bin/bash testuser
WORKDIR /work
RUN chown testuser:testuser /work
USER testuser
