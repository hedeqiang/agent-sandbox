#!/bin/bash
set -e

# ============================================================
# Codex 第三方中转配置
#
# Codex 不支持用 OPENAI_BASE_URL 环境变量指定第三方地址，
# 必须写入 ~/.codex/config.toml（provider 配置）和
# ~/.codex/auth.json（API Key）。
# 这里在容器启动时根据 .env 中的环境变量自动生成。
# ============================================================

CODEX_HOME="$HOME/.codex"
CONFIG="$CODEX_HOME/config.toml"
AUTH="$CODEX_HOME/auth.json"
MARKER="# generated-by: agent-sandbox"

if [ -n "$CODEX_BASE_URL" ] && [ -n "$OPENAI_API_KEY" ]; then
    mkdir -p "$CODEX_HOME"

    # 仅当 config.toml 不存在、或此前由本脚本生成时才覆盖，
    # 避免破坏手动维护的配置（手动接管时删除 marker 行即可）
    if [ ! -f "$CONFIG" ] || grep -qF "$MARKER" "$CONFIG"; then
        {
            echo "$MARKER  (auto-generated from .env; delete this line to manage manually)"
            echo 'model_provider = "OpenAI"'
            if [ -n "$CODEX_MODEL" ]; then
                echo "model = \"$CODEX_MODEL\""
                echo "review_model = \"$CODEX_MODEL\""
            fi
            if [ -n "$CODEX_MODEL_REASONING_EFFORT" ]; then
                echo "model_reasoning_effort = \"$CODEX_MODEL_REASONING_EFFORT\""
            fi
            echo 'disable_response_storage = true'
            echo ''
            echo '[model_providers.OpenAI]'
            echo 'name = "OpenAI"'
            echo "base_url = \"$CODEX_BASE_URL\""
            echo "wire_api = \"${CODEX_WIRE_API:-responses}\""
            echo 'requires_openai_auth = true'
        } > "$CONFIG"
        echo "[entrypoint] generated $CONFIG (base_url=$CODEX_BASE_URL)"
    fi

    # 仅当 auth.json 不存在、或不含 ChatGPT 登录 token 时才覆盖，
    # 避免冲掉已有的 ChatGPT 账号登录凭证
    if [ ! -f "$AUTH" ] || ! grep -q '"tokens"' "$AUTH"; then
        printf '{\n  "OPENAI_API_KEY": "%s"\n}\n' "$OPENAI_API_KEY" > "$AUTH"
        chmod 600 "$AUTH"
        echo "[entrypoint] generated $AUTH"
    fi
fi

exec "$@"
