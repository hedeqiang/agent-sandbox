# Agent Sandbox

English | [简体中文](README.zh-CN.md)

A sandboxed Ubuntu container for running AI coding agents — [Claude Code](https://claude.com/claude-code) and [OpenAI Codex CLI](https://github.com/openai/codex) — pre-installed and ready to use. Code and credentials are persisted on the host, so the container can be destroyed and rebuilt at any time.

## Features

- 🐧 Based on Ubuntu 24.04, with common dev tools pre-installed (git, vim, ripgrep, jq, python3, build-essential, etc.)
- 🤖 Claude Code + Codex CLI both installed by default — each can be toggled off or version-pinned via build args
- 📦 Node.js 22 runtime
- 👤 Runs as non-root user `agent` (with passwordless sudo)
- 🔑 Flexible authentication: OAuth / ChatGPT login, official API keys, or third-party API gateways
- 💾 Login credentials persisted in a Docker volume — no re-login after rebuilding the container
- 📁 Host `./workspace` directory mounted as the working directory inside the container

## Directory Structure

```
.
├── Dockerfile          # Ubuntu + Node.js + Claude Code + Codex image
├── docker-compose.yml  # Container orchestration
├── entrypoint.sh       # Generates Codex gateway config from env vars on startup
├── .env.example        # Build & authentication config template
├── workspace/          # Working directory (mounted at /workspace in the container)
└── README.md
```

## Quick Start

### 1. Configure (optional)

```bash
cp .env.example .env
```

**Install toggles & versions** (build-time, all installed at latest by default):

```dotenv
# INSTALL_CLAUDE_CODE=true
# INSTALL_CODEX=true
# CLAUDE_CODE_VERSION=2.1.162
# CODEX_VERSION=0.46.0
```

**Claude Code authentication** (pick one):

```dotenv
# Option 1: OAuth login (recommended) — leave empty, log in via browser on first run

# Option 2: Official Anthropic API key
# ANTHROPIC_API_KEY=sk-ant-xxxxxxxx

# Option 3: Third-party API gateway
# ANTHROPIC_BASE_URL=https://api.example.com
# ANTHROPIC_AUTH_TOKEN=sk-xxxxxxxx
# Optional custom model names (required by some gateways):
# ANTHROPIC_MODEL=claude-opus-4-8
# ANTHROPIC_SMALL_FAST_MODEL=claude-haiku-4-5-20251001
```

**Codex authentication** (pick one):

```dotenv
# Option 1: ChatGPT login — leave empty, log in on first run

# Option 2: API key (official or third-party gateway)
# OPENAI_API_KEY=sk-xxxxxxxx
# CODEX_BASE_URL=https://api.example.com

# Optional: model name / wire API (responses or chat, default responses) / reasoning effort
# CODEX_MODEL=gpt-5.5
# CODEX_WIRE_API=responses
# CODEX_MODEL_REASONING_EFFORT=xhigh
```

> Note: Codex does **not** honor the `OPENAI_BASE_URL` env var. When `CODEX_BASE_URL` + `OPENAI_API_KEY` are set, the container entrypoint auto-generates `~/.codex/config.toml` (provider config) and `~/.codex/auth.json` (API key) on startup. To manage these files manually, delete the `# generated-by: agent-sandbox` marker line in `config.toml` and the entrypoint will leave them untouched.

### 2. Build and start

```bash
docker compose up -d --build
```

### 3. Enter the container

```bash
docker compose exec agent-sandbox bash

# Inside the container
claude   # Claude Code
codex    # Codex CLI
```

Put the projects you want to work on into the host's `workspace/` directory — they will be available under `/workspace` inside the container.

## Common Operations

| Operation | Command |
|------|------|
| Start the container | `docker compose up -d` |
| Enter the container | `docker compose exec agent-sandbox bash` |
| Launch Claude Code directly | `docker compose exec agent-sandbox claude` |
| Launch Codex directly | `docker compose exec agent-sandbox codex` |
| Stop the container | `docker compose down` |
| Rebuild the image | `docker compose up -d --build` |
| Update Claude Code | Inside: `sudo npm update -g @anthropic-ai/claude-code` |
| Update Codex | Inside: `sudo npm update -g @openai/codex` |
| View logs | `docker compose logs -f` |
| Full cleanup (including credentials) | `docker compose down -v` |

After changing authentication settings in `.env`, simply run `docker compose up -d` to recreate the container. Changing install toggles or versions requires a rebuild with `docker compose up -d --build`.

## Optional Configuration

The following mounts are available in `docker-compose.yml` — uncomment as needed:

```yaml
# Reuse the host's git config
- ~/.gitconfig:/home/agent/.gitconfig:ro
# Reuse the host's SSH keys (for cloning private repos)
- ~/.ssh:/home/agent/.ssh:ro
```

## Notes

- `.env` contains secrets and is already in `.gitignore` — do not commit it to version control
- Login credentials (`~/.claude/`, `~/.claude.json`, `~/.codex/`) are stored in the named volume `agent-home`; `docker compose down` keeps it, only `down -v` removes it
- Third-party Anthropic gateways use `ANTHROPIC_AUTH_TOKEN` instead of `ANTHROPIC_API_KEY` — this is Claude Code's standard convention for custom gateways
- The `agent` user inside the container has passwordless sudo, so you can easily install extra dependencies
