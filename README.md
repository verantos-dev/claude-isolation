# claude-isolation

Run Claude Code in an isolated Docker container with full autonomy — no permission prompts, no risk to your host system.

## Why use this?

Claude Code's `--dangerously-skip-permissions` flag lets Claude work autonomously — installing packages, editing files, running commands — without asking for approval at every step. This is powerful but risky on a bare machine.

This project solves that by running Claude inside a disposable Docker container. Claude gets full freedom to do its work, while your host machine stays completely untouched. When the container exits, everything is gone. You get the productivity of a fully autonomous coding agent with the safety of complete isolation.

## Prerequisites

- Docker installed and running
- A GitHub Personal Access Token (PAT) with repo access

## Quick Start

### 1. Build the image

```bash
# If using limactl with multi-arch support:
docker build -t claude:local --platform linux/amd64 .

# Otherwise:
docker build -t claude:local .
```

### 2. Set environment variables

| Variable | Purpose | Default |
|---|---|---|
| `GH_PAT` | GitHub Personal Access Token for cloning | *(required)* |
| `GH_REPO` | Repo to clone (e.g. `github.com/org/repo.git`) | `github.com/verantos-dev/verantos-evidence-platform.git` |
| `GH_BRANCH` | Branch to checkout | `main` |

```bash
export GH_PAT=ghp_your_token_here
export GH_REPO=github.com/your-org/your-repo.git
export GH_BRANCH=main
```

### 3. Run the container

```bash
docker run --rm -it \
  -e GH_PAT=${GH_PAT} \
  -e GH_BRANCH=${GH_BRANCH} \
  -e GH_REPO=${GH_REPO} \
  claude:local
```

> If using limactl with multi-arch support, add `--platform linux/amd64` to both the `build` and `run` commands.

## What happens at startup

The container entry point (`startup_script.sh`) will:

1. Clone your repo using the PAT
2. Checkout the specified branch
3. Run `pnpm install`
4. Launch Claude Code with `--dangerously-skip-permissions`

## Included tooling

The image ships with:

- **Node.js 22** with pnpm, TypeScript, ESLint, Prettier
- **Python 3** with requests, python-dotenv, Semgrep
- **Solidity** — Foundry (forge, cast, anvil), solc-select, solhint
- **General** — git, curl, wget, build-essential

## Customization

### Startup script

Edit `startup_script.sh` to change what runs when the container starts (e.g. use a different package manager, add setup steps). Rebuild the image after changes.

### MCP servers

The Dockerfile has commented-out sections for adding custom MCP servers. Uncomment and configure as needed, then add the server config to `claude-config.json` under `mcpServers`.

### Configuration files

- **`claude-config.json`** — Claude Code's main config. Pre-configured to auto-accept all permissions and tools in `/workspace`.
- **`settings.local.json`** — Project-level permission overrides (currently empty).

## Security notes

The container runs as a non-root user (`claude`) with several hardening measures:

- Setuid/setgid binaries removed
- Network reconnaissance tools removed
- Core dumps disabled
- Process tracing restricted
- Signal handling via `dumb-init`
