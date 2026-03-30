FROM node:22-slim

RUN apt-get update && apt-get install -y git jq && rm -rf /var/lib/apt/lists/*
RUN npm install -g @anthropic-ai/claude-code

# The contree plugin source is mounted at runtime, not baked in
WORKDIR /work
