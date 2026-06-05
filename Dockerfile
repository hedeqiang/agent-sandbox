FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# 基础工具 + 常用开发依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    vim \
    nano \
    jq \
    ripgrep \
    unzip \
    zip \
    openssh-client \
    gnupg \
    sudo \
    build-essential \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# 安装 Node.js 22 (Claude Code / Codex 均需要 Node 18+)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# 创建非 root 用户（CLI Agent 不建议以 root 运行）
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 agent \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent

# ===== AI Coding Agent 安装开关（默认全部安装）=====
ARG INSTALL_CLAUDE_CODE=true
ARG CLAUDE_CODE_VERSION=latest
ARG INSTALL_CODEX=true
ARG CODEX_VERSION=latest

# Claude Code
RUN if [ "$INSTALL_CLAUDE_CODE" = "true" ]; then \
        npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}; \
    fi

# OpenAI Codex CLI
RUN if [ "$INSTALL_CODEX" = "true" ]; then \
        npm install -g @openai/codex@${CODEX_VERSION}; \
    fi

# 入口脚本：启动时根据环境变量生成 Codex 第三方中转配置
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER agent
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# 保持容器运行，方便随时 exec 进去
CMD ["sleep", "infinity"]
