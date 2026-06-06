#!/bin/bash
set -euo pipefail

# ============================================================
# Codex 第三方中转配置
#
# Codex 不支持用 OPENAI_BASE_URL 环境变量指定第三方地址，
# 必须写入 ~/.codex/config.toml（provider 配置）和
# ~/.codex/auth.json（API Key）。
# 这里在容器启动时根据环境变量渲染模板自动生成。
# ============================================================

CODEX_HOME="$HOME/.codex"
CONFIG="$CODEX_HOME/config.toml"
AUTH="$CODEX_HOME/auth.json"
MARKER="# generated-by: agent-sandbox"
TMPL_DIR="/usr/local/share/agent-sandbox/templates"

# 渲染模板文件：将 ${VAR} 和 ${VAR:-default} 替换为环境变量值，
# 并对目标格式做正确转义。TOML 格式还会自动删除值为空的可选字段行。
render_template() {
    local tmpl="$1" out="$2" fmt="$3"
    python3 - "$tmpl" "$out" "$fmt" <<'PYEOF'
import sys, os, re, json

def json_escape(val):
    return json.dumps(val)[1:-1]  # 借助标准库获得正确的 JSON 字符串转义

def toml_escape(val):
    return val.replace('\\', '\\\\').replace('"', '\\"') \
              .replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')

def resolve(expr):
    # 支持 ${VAR:-default} 语法，与 bash 行为一致（空值也走 default）
    if ':-' in expr:
        key, default = expr.split(':-', 1)
        return os.environ.get(key) or default
    return os.environ.get(expr, '')

tmpl_path, out_path, fmt = sys.argv[1], sys.argv[2], sys.argv[3]
escape_fn = json_escape if fmt == 'json' else toml_escape

with open(tmpl_path) as f:
    content = f.read()

rendered = re.sub(r'\$\{([^}]+)\}', lambda m: escape_fn(resolve(m.group(1))), content)

# TOML：删除值为空字符串的可选字段行（如 model = ""）
if fmt == 'toml':
    lines = [l for l in rendered.splitlines(keepends=True)
             if not re.match(r'^\w[\w_]* = ""$', l.rstrip())]
    rendered = ''.join(lines)

with open(out_path, 'w') as f:
    f.write(rendered)
PYEOF
}

if [ -n "${CODEX_BASE_URL:-}" ] && [ -n "${OPENAI_API_KEY:-}" ]; then
    mkdir -p "$CODEX_HOME"

    # 仅当 config.toml 不存在、或此前由本脚本生成时才覆盖，
    # 避免破坏手动维护的配置（手动接管时删除 marker 行即可）
    if [ ! -f "$CONFIG" ] || grep -qF "$MARKER" "$CONFIG"; then
        render_template "$TMPL_DIR/codex/config.toml.tmpl" "$CONFIG" toml
        echo "[entrypoint] generated $CONFIG (base_url=${CODEX_BASE_URL})"
    fi

    # 仅当 auth.json 不存在、或不含 ChatGPT 登录 token 时才覆盖，
    # 避免冲掉已有的 ChatGPT 账号登录凭证
    if [ ! -f "$AUTH" ] || ! jq -e 'has("tokens")' "$AUTH" > /dev/null 2>&1; then
        render_template "$TMPL_DIR/codex/auth.json.tmpl" "$AUTH" json
        chmod 600 "$AUTH"
        echo "[entrypoint] generated $AUTH"
    fi
fi

exec "$@"
