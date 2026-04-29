# Containerized AI agents

This repository provides single-file shell scripts that launch AI agents inside disposable Docker containers.

## What this gives you

- No separate `Dockerfile` or `docker-compose.yml` is needed.
- The container image is defined directly inside each script.
- The current working folder is mounted to `/workspace` inside the container.
- Agent host configs are mounted into the container so settings like auth, model selection, and local state stay in sync.
- Ollama models can stay on the host machine while the agent runs in Docker.
- The container is removed automatically after the agent exits because it runs with `--rm`.

## Available scripts

- `opencode-agent.sh` launches the OpenCode agent.
- `pi-agent.sh` launches the Pi coding agent.

## How it works

Each script is self-contained:

1. It captures the current directory as the workspace.
2. It builds a minimal Docker image inline from a heredoc Dockerfile.
3. It mounts the workspace at `/workspace`.
4. It mounts the relevant host config directories so the agent keeps using your local settings.
5. It exposes the host machine to the container as `host.docker.internal` and sets `OLLAMA_HOST` so the agent can reach a host Ollama server.
6. It starts the agent in an interactive container that is deleted on exit.

## Usage

Run the script you want from the repository root or from any project directory you want the agent to work on. All scripts support a -r/--rebuild flag to force rebuilding the container image before launching.

Examples:

```bash
opencode-agent.sh
pi-agent.sh

# Force rebuild of the container image
opencode-agent.sh -r
pi-agent.sh --rebuild
```

Because the current folder is mounted into the container, run the script from the project you want the agent to inspect or modify.

## Using Ollama on the host machine

Both scripts are set up to use an Ollama server running on the host machine.

- By default, the container connects to `http://host.docker.internal:11434`.
- The scripts pass `OLLAMA_HOST` into the container automatically.
- If your Ollama server listens on a different port, set `OLLAMA_PORT` before launching the agent.

Examples:

```bash
# Default Ollama port
opencode-agent.sh

# Custom Ollama port on the host
OLLAMA_PORT=11500 pi-agent.sh
```

Make sure Ollama is running on the host before starting the containerized agent.

## Notes

- The scripts expect Docker to be available locally.
- If you want to use local Ollama models, Ollama must also be running on the host machine.
- The first run may take longer because the image is built and dependencies are installed inside the container.
- Use the -r or --rebuild flag to force rebuilding the container image (useful after script updates or when you want to pick up upstream image or agent changes).
- Any settings stored in the mounted config directories will persist between runs even though the container itself is ephemeral.
