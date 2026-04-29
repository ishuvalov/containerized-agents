#!/usr/bin/env bash

# Launches the OpenCode AI agent in a Docker container.
# Mounts the current workspace and config directories to persist agent state.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

IMAGE_NAME="opencode-agent"
CONTAINER_NAME="opencode"
OPENCODE_PACKAGE="opencode-ai@latest"

NODE_VERSION="24-slim"
NPM_GLOBAL="/home/node/.npm-global"
BUN_SYSTEM_BIN="/usr/local/bin/bun"

CONTAINER_PATH="${NPM_GLOBAL}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Ollama defaults — override with env vars if needed
OLLAMA_PORT="${OLLAMA_PORT:-11434}"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

usage() {
cat <<'EOF'
Usage: ./opencode-agent.sh [--rebuild|-r]

Launch the OpenCode AI agent in Docker.

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
OPENCODE_CONFIG="$HOME/.config/opencode"
OPENCODE_DATA="$HOME/.local/share/opencode"
OPENCODE_STATE="$HOME/.local/state/opencode"

mkdir -p "$OPENCODE_CONFIG" "$OPENCODE_DATA" "$OPENCODE_STATE"

# ---------------------------------------------------------------------------
# Build image
# ---------------------------------------------------------------------------

build_image() {
  docker pull "node:${NODE_VERSION}"

  docker build --no-cache -t "$IMAGE_NAME" - <<DOCKERFILE
FROM node:${NODE_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \\
      git ripgrep fzf fd-find curl ca-certificates unzip \\
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \\
    && rm -rf /var/lib/apt/lists/* \\
    && curl -fsSL https://bun.sh/install | bash \\
    && mv /root/.bun/bin/bun ${BUN_SYSTEM_BIN} \\
    && rm -rf /root/.bun \\
    && npm config set prefix ${NPM_GLOBAL} \\
    && npm install -g ${OPENCODE_PACKAGE} \\
    && mkdir -p \\
         /home/node/.config/opencode \\
         /home/node/.local/share/opencode/bin \\
         /home/node/.local/state/opencode \\
         /home/node/.cache/opencode/bin \\
    && chown -R node:node /home/node

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
# Build docker run arguments
# ---------------------------------------------------------------------------

DOCKER_ARGS=(
  --rm -it
  --name "$CONTAINER_NAME"
  -e HOME=/home/node
  -e PATH="${CONTAINER_PATH}"
  -e npm_config_prefix="${NPM_GLOBAL}"
  # Resolve host.docker.internal -> host machine IP
  --add-host "host.docker.internal:host-gateway"
  # Tell the agent (and any Ollama client libs) where Ollama lives
  -e "OLLAMA_HOST=http://host.docker.internal:${OLLAMA_PORT}"
  -v "$WORKSPACE:/workspace"
  -v "$OPENCODE_CONFIG:/home/node/.config/opencode"
  -v "$OPENCODE_DATA:/home/node/.local/share/opencode"
  -v "$OPENCODE_STATE:/home/node/.local/state/opencode"
  -v "opencode-cache:/home/node/.cache/opencode"
  --cap-drop=ALL
  --security-opt no-new-privileges:true
  --pids-limit=128
)

# ---------------------------------------------------------------------------
# Run container
# ---------------------------------------------------------------------------

docker run "${DOCKER_ARGS[@]}" \
  "$IMAGE_NAME" \
  "${NPM_GLOBAL}/bin/opencode"