#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="$(pwd)"
OPENCODE_CONFIG="$HOME/.config/opencode"
OPENCODE_DATA="$HOME/.local/share/opencode"
OPENCODE_STATE="$HOME/.local/state/opencode"

mkdir -p "$OPENCODE_CONFIG" "$OPENCODE_DATA" "$OPENCODE_STATE"

docker pull node:24-slim

docker build -t opencode-agent - <<'DOCKERFILE'
FROM node:24-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      git ripgrep fzf fd-find curl ca-certificates unzip \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://bun.sh/install | bash \
    && mv /root/.bun/bin/bun /usr/local/bin/bun \
    && rm -rf /root/.bun \
    && npm config set prefix /home/node/.npm-global \
    && npm install -g opencode-ai@latest \
    && mkdir -p \
         /home/node/.config/opencode \
         /home/node/.local/share/opencode/bin \
         /home/node/.local/state/opencode \
         /home/node/.cache/opencode/bin \
    && chown -R node:node /home/node

USER node
ENV PATH="/home/node/.npm-global/bin:/usr/local/bin:$PATH"
ENV npm_config_prefix="/home/node/.npm-global"
WORKDIR /workspace
DOCKERFILE

docker run --rm -it \
  --name opencode \
  -e HOME=/home/node \
  -e PATH="/home/node/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  -e npm_config_prefix="/home/node/.npm-global" \
  -v "$WORKSPACE:/workspace" \
  -v "$OPENCODE_CONFIG:/home/node/.config/opencode" \
  -v "$OPENCODE_DATA:/home/node/.local/share/opencode" \
  -v "$OPENCODE_STATE:/home/node/.local/state/opencode" \
  -v "opencode-cache:/home/node/.cache/opencode" \
  --cap-drop=ALL \
  --security-opt no-new-privileges:true \
  --pids-limit=128 \
  opencode-agent \
  /home/node/.npm-global/bin/opencode