#!/usr/bin/env bash

# Launches the Pi coding agent in a Docker container.
# Mounts the current workspace and a config directory to persist agent state.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

IMAGE_NAME="pi-agent"
CONTAINER_NAME="pi"
PI_PACKAGE="@mariozechner/pi-coding-agent"

NODE_VERSION="24-alpine"
NPM_GLOBAL="/home/node/.npm-global"
BUN_SYSTEM_BIN="/usr/local/bin/bun"

CONTAINER_PATH="/root/.bun/bin:${NPM_GLOBAL}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

usage() {
cat <<'EOF'
Usage: ./pi-agent.sh [--rebuild|-r]

Launch the Pi coding agent in Docker.

Options:
  -r, --rebuild   Rebuild the container image without using the build cache
  -h, --help      Show this help message
EOF
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

# ---------------------------------------------------------------------------
# Runtime paths (resolved after argument parsing)
# ---------------------------------------------------------------------------

WORKSPACE="$(pwd)"
PI_CONFIG="$HOME/.pi"

mkdir -p "$PI_CONFIG"

# ---------------------------------------------------------------------------
# Build image
# ---------------------------------------------------------------------------

build_image() {
  docker build --no-cache -t "$IMAGE_NAME" - <<DOCKERFILE
FROM node:${NODE_VERSION}

# Install system tools; bash is required by the bun installer
RUN apk add --no-cache \\
    fzf \\
    fd \\
    ripgrep \\
    curl \\
    bash \\
    unzip \\
    git && \\
    npm config set prefix ${NPM_GLOBAL} && \\
    npm install -g ${PI_PACKAGE} && \\
    chown -R node:node /home/node

# Install bun and make it available system-wide
RUN curl -fsSL https://bun.sh/install | bash \\
    && mv /root/.bun/bin/bun ${BUN_SYSTEM_BIN} \\
    && rm -rf /root/.bun

ENV PATH="${CONTAINER_PATH}"

USER node
ENV PATH="${CONTAINER_PATH}"
ENV npm_config_prefix="${NPM_GLOBAL}"

WORKDIR /workspace
DOCKERFILE
}

if [[ "$REBUILD" == true ]] || ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  build_image
fi

# ---------------------------------------------------------------------------
# Run container
# ---------------------------------------------------------------------------

docker run --rm -it \
  --name "$CONTAINER_NAME" \
  -e HOME=/home/node \
  -e PATH="${CONTAINER_PATH}" \
  -e npm_config_prefix="${NPM_GLOBAL}" \
  -v "$WORKSPACE:/workspace" \
  -v "$PI_CONFIG:/home/node/.pi" \
  -v "pi-agent-bin:/home/node/.pi/agent/bin" \
  --cap-drop=ALL \
  --security-opt no-new-privileges:true \
  --pids-limit=128 \
  "$IMAGE_NAME" \
  pi
