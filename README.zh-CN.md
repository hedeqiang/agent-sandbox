# Agent Sandbox

[English](README.md) | 简体中文

在 Ubuntu 容器中运行 AI 编程 Agent 的沙箱环境，预装 [Claude Code](https://claude.com/claude-code) 和 [OpenAI Codex CLI](https://github.com/openai/codex)，开箱即用。代码和凭证持久化在宿主机，容器可随时销毁重建。

## 特性

- 🐧 基于 Ubuntu 24.04，预装常用开发工具（git、vim、ripgrep、jq、python3、build-essential 等）
- 🤖 默认同时安装 Claude Code + Codex CLI，可分别通过构建参数关闭或固定版本
- 📦 Node.js 22 运行时
- 👤 以非 root 用户 `agent` 运行（有免密 sudo）
- 🔑 灵活认证：OAuth / ChatGPT 账号登录、官方 API Key、第三方中转 API
- 💾 登录凭证持久化到 Docker 卷，重建容器无需重新登录
- 📁 宿主机 `./workspace` 目录挂载为容器内工作目录

## 目录结构

```
.
├── Dockerfile          # Ubuntu + Node.js + Claude Code + Codex 镜像
├── docker-compose.yml  # 容器编排配置
├── entrypoint.sh       # 启动时根据环境变量生成 Codex 中转配置
├── sandbox             # 在任意目录启动沙箱的 wrapper 脚本
├── .env.example        # 构建与认证配置模板
├── workspace/          # 工作目录（挂载到容器内 /workspace）
└── README.md
```

## 快速开始

### 1. 配置（可选）

```bash
cp .env.example .env
```

**安装开关与版本**（构建时生效，默认全部安装最新版）：

```dotenv
# INSTALL_CLAUDE_CODE=true
# INSTALL_CODEX=true
# CLAUDE_CODE_VERSION=2.1.162
# CODEX_VERSION=0.46.0
```

**Claude Code 认证**（三选一）：

```dotenv
# 方式一：OAuth 登录（推荐）—— 留空，首次运行时在浏览器登录

# 方式二：Anthropic 官方 API Key
# ANTHROPIC_API_KEY=sk-ant-xxxxxxxx

# 方式三：第三方中转 API
# ANTHROPIC_BASE_URL=https://api.example.com
# ANTHROPIC_AUTH_TOKEN=sk-xxxxxxxx
# 可选：自定义模型名（部分中转服务需要）
# ANTHROPIC_MODEL=claude-opus-4-8
# ANTHROPIC_SMALL_FAST_MODEL=claude-haiku-4-5-20251001
```

**Codex 认证**（二选一）：

```dotenv
# 方式一：ChatGPT 账号登录 —— 留空，首次运行时按提示登录

# 方式二：API Key（官方或第三方中转）
# OPENAI_API_KEY=sk-xxxxxxxx
# CODEX_BASE_URL=https://api.example.com

# 可选：模型名 / wire API（responses 或 chat，默认 responses）/ 推理强度
# CODEX_MODEL=gpt-5.5
# CODEX_WIRE_API=responses
# CODEX_MODEL_REASONING_EFFORT=xhigh
```

> 注意：Codex **不认** `OPENAI_BASE_URL` 环境变量。设置 `CODEX_BASE_URL` + `OPENAI_API_KEY` 后，容器入口脚本会在启动时自动生成 `~/.codex/config.toml`（provider 配置）和 `~/.codex/auth.json`（API Key）。如需手动维护这两个文件，删除 `config.toml` 中的 `# generated-by: agent-sandbox` 标记行即可，入口脚本将不再覆盖。

### 2. 构建并启动

```bash
docker compose up -d --build
```

### 3. 进入容器使用

```bash
docker compose exec agent-sandbox bash

# 容器内
claude   # Claude Code
codex    # Codex CLI
```

把要处理的项目放进宿主机的 `workspace/` 目录，容器内在 `/workspace` 下即可访问。

## 在任意目录使用（推荐）

如果不想把代码都塞进固定的 `workspace/`，可以用项目里的 `sandbox` 脚本：它会把**你当前所在的目录**挂载进容器，并复用持久化的 `agent-home` 卷（登录凭证不丢），容器用完即删。

一次性把脚本软链到 PATH：

```bash
ln -s "$(pwd)/sandbox" /opt/homebrew/bin/sandbox   # 路径按你的环境调整
```

> 用软链（`ln -s`）而非拷贝，脚本才能找到项目里的 `.env` 和 `docker-compose.yml`。

之后在任意目录使用：

```bash
cd ~/任意/项目目录
sandbox          # 进容器 bash，当前目录即 /workspace
sandbox claude   # 直接起 Claude Code
sandbox codex    # 直接起 Codex CLI
```

首次运行若镜像未构建，脚本会自动 `docker compose build`（读取 `.env` 的安装开关/版本）。每个目录是独立的一次性容器，可同时开多个；凭证共享同一个 `agent-home` 卷，换目录无需重新登录。

> 与下方 `docker compose` 方式的区别：compose 跑的是固定挂载 `./workspace` 的常驻容器；`sandbox` 跑的是挂载当前目录的一次性容器。两者可共存，共享同一份凭证卷。

## 常用操作

| 操作 | 命令 |
|------|------|
| 启动容器 | `docker compose up -d` |
| 进入容器 | `docker compose exec agent-sandbox bash` |
| 直接启动 Claude Code | `docker compose exec agent-sandbox claude` |
| 直接启动 Codex | `docker compose exec agent-sandbox codex` |
| 停止容器 | `docker compose down` |
| 重新构建镜像 | `docker compose up -d --build` |
| 更新 Claude Code | 进容器后 `sudo npm update -g @anthropic-ai/claude-code` |
| 更新 Codex | 进容器后 `sudo npm update -g @openai/codex` |
| 查看日志 | `docker compose logs -f` |
| 彻底清除（含登录凭证） | `docker compose down -v` |

修改 `.env` 中的认证配置后只需 `docker compose up -d` 重建容器即可生效；修改安装开关或版本则需要 `docker compose up -d --build` 重新构建镜像。

## 可选配置

`docker-compose.yml` 中预留了以下挂载，按需取消注释：

```yaml
# 复用宿主机 git 配置
- ~/.gitconfig:/home/agent/.gitconfig:ro
# 复用宿主机 SSH key（用于 git clone 私有仓库）
- ~/.ssh:/home/agent/.ssh:ro
```

## 注意事项

- `.env` 包含密钥，已加入 `.gitignore`，请勿提交到版本库
- 登录凭证（`~/.claude/`、`~/.claude.json`、`~/.codex/`）保存在命名卷 `agent-home` 中，`docker compose down` 不会删除；只有 `down -v` 才会清除
- 第三方 Anthropic 中转使用 `ANTHROPIC_AUTH_TOKEN` 而非 `ANTHROPIC_API_KEY`，这是 Claude Code 对自定义网关的标准约定
- 容器内 `agent` 用户拥有免密 sudo，方便安装额外依赖
