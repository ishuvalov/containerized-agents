# Containerized AI agents

This repository provides single-file shell scripts that launch AI agents inside disposable Docker containers.

## What this gives you

- No separate `Dockerfile` or `docker-compose.yml` is needed.
- The container image is defined directly inside each script.
- The current working folder is mounted to `/workspace` inside the container.
- Agent host configs are mounted into the container so settings like auth, model selection, and local state stay in sync.
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
5. It starts the agent in an interactive container that is deleted on exit.

## Usage

Run the script you want from the repository root or from any project directory you want the agent to work on:

```bash
./opencode-agent.sh
./pi-agent.sh
```

Because the current folder is mounted into the container, run the script from the project you want the agent to inspect or modify.

## Notes

- The scripts expect Docker to be available locally.
- The first run may take longer because the image is built and dependencies are installed inside the container.
- Any settings stored in the mounted config directories will persist between runs even though the container itself is ephemeral.
