#!/usr/bin/env bash

# Script to launch Pi coding agent in a Docker container.
# It mounts the current workspace and a config directory to persist agent state.

set -euo pipefail

usage() {
  echo "Usage: $0 [--rebuild|-r]"
}

REBUILD=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--rebuild)
      REBUILD=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

WORKSPACE="$(pwd)"
PI_CONFIG="$HOME/.pi"

mkdir -p "$PI_CONFIG"

if [[ "$REBUILD" == true ]] || ! docker image inspect pi-agent >/dev/null 2>&1; then
  docker build --no-cache -t pi-agent - <<'DOCKERFILE'
FROM node:24-alpine

# Install dependencies (bash is required for bun installer)
RUN apk add --no-cache \
    fzf \
    fd \
    ripgrep \
    curl \
    bash \
    unzip \
    git && \
    npm config set prefix /home/node/.npm-global && \
    npm install -g @mariozechner/pi-coding-agent && \
    chown -R node:node /home/node

# Also install bun
RUN curl -fsSL https://bun.sh/install | bash \
    && mv /root/.bun/bin/bun /usr/local/bin/bun \
    && rm -rf /root/.bun

# Make bun available for node user
ENV PATH="/root/.bun/bin:/home/node/.npm-global/bin:$PATH"

USER node
ENV PATH="/root/.bun/bin:/home/node/.npm-global/bin:$PATH"
ENV npm_config_prefix="/home/node/.npm-global"

WORKDIR /workspace
DOCKERFILE
fi

docker run --rm -it \
  --name pi \
  -e HOME=/home/node \
  -e PATH="/root/.bun/bin:/home/node/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  -e npm_config_prefix="/home/node/.npm-global" \
  -v "$WORKSPACE:/workspace" \
  -v "$PI_CONFIG:/home/node/.pi" \
  -v "pi-agent-bin:/home/node/.pi/agent/bin" \
  --cap-drop=ALL \
  --security-opt no-new-privileges:true \
  --pids-limit=128 \
  pi-agent \
  pi
