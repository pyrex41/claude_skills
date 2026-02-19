# AI Harnesses for Ralph

Ralph works with multiple AI coding CLIs. Choose based on your needs.

## Claude Code (Recommended)

Anthropic's official CLI for Claude.

```bash
# Install
npm install -g @anthropic-ai/claude-code

# Usage
./loop.sh --harness claude --plan
./loop.sh --harness claude --build --allow-subtasks
```

**Pros:**
- Best agentic capabilities
- Native subagent support (Task tool)
- Fine-grained tool permissions
- Extended thinking (Ultrathink)

**Tool permissions by mode:**

| Mode | Allowed Tools |
|------|---------------|
| Plan | Read, Glob, Grep, Task, WebFetch, WebSearch |
| Build | Edit, Write, Bash, Read, Glob, Grep |
| Build + subtasks | Edit, Write, Bash, Read, Glob, Grep, Task |
| Dangerous | All tools, no prompts |

---

## OpenCode

Multi-model agentic coding CLI. Supports OpenAI, Anthropic, Google, xAI, and others.

```bash
# Install
curl -fsSL https://opencode.ai/install | bash

# Check available models
opencode models

# Usage (server mode — recommended for Ralph loops)
./loop.sh --harness opencode --model xai/grok-code-fast-1
./loop.sh --harness opencode --model anthropic/claude-sonnet-4-6
```

**Model format:** `provider/model` (e.g. `xai/grok-code-fast-1`, `openai/gpt-4o`, `anthropic/claude-sonnet-4-6`).
For the HTTP API, split on `/`: `providerID="xai"`, `modelID="grok-code-fast-1"`.
Do NOT double-prefix — `providerID:"xai"` + `modelID:"xai/grok-code-fast-1"` will fail.

**Pros:**
- Model flexibility across providers
- Persistent server mode avoids per-iteration startup cost
- HTTP API enables clean session management

**Cons:**
- No native subagent support
- `opencode run` may emit "reasoning part not found" errors for some models — use server mode instead
- `opencode serve` does not accept a path argument — `cd` to workspace before starting

### Server Mode (Recommended for Ralph Loops)

Start the server once, create a new session per iteration, POST the prompt and block until done:

```bash
# 1. Start server from workspace root
cd /path/to/project
opencode serve --port 4096 --hostname 127.0.0.1 &

# 2. Create session
SESSION=$(curl -sf -X POST http://localhost:4096/session \
  -H "Content-Type: application/json" \
  -d '{"title": "ralph-build-1"}')
SESSION_ID=$(echo "$SESSION" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

# 3. Send prompt and wait for completion (blocks until agent finishes)
# Write body to temp file to avoid shell quoting issues
python3 - /path/to/PROMPT_build.md > /tmp/body.json <<'PYEOF'
import json, sys
prompt = open(sys.argv[1]).read()
print(json.dumps({
    "model": {"providerID": "xai", "modelID": "grok-code-fast-1"},
    "parts": [{"type": "text", "text": prompt}]
}))
PYEOF

curl -s -X POST "http://localhost:4096/session/$SESSION_ID/message" \
  -H "Content-Type: application/json" \
  -d "@/tmp/body.json"
```

**API endpoints:**
- `POST /session` — create session (`{"title": "..."}`)
- `POST /session/:id/message` — send prompt, blocks until complete
  - Body: `{"model": {"providerID": "...", "modelID": "..."}, "parts": [{"type": "text", "text": "..."}]}`
- `GET /session/:id/message` — list messages

**Debugging curl:**
Use `-s -w "\n__STATUS:%{http_code}"` instead of `-sf` to see HTTP errors without silent failure.

### `opencode run` (Simple, But Has Caveats)

```bash
opencode run -m xai/grok-code-fast-1 "$(cat PROMPT_build.md)"
```

Works for one-shot use but may produce "reasoning part not found" errors for models that emit reasoning tokens (e.g. grok-code-fast-1). Prefer server mode for loops.

---

## Codex CLI

OpenAI's coding agent CLI.

```bash
# Install
npm install -g @openai/codex

# Usage
./loop.sh --harness codex --model o1
./loop.sh --harness codex --model o1-mini
```

**Available models:**
- `o1` - Full reasoning model (slower, more thorough)
- `o1-mini` - Faster reasoning model
- `gpt-4`, `gpt-4-turbo`

**Approval modes:**
- `suggest` - Show changes, require approval (plan mode)
- `auto-edit` - Auto-approve file edits (build mode)
- `full-auto` - Auto-approve everything (dangerous mode)

**Pros:**
- Good reasoning with o1 models
- Native sandbox support

**Cons:**
- No subagent support
- Slower with o1

---

## Custom Harness

Use any CLI that accepts a prompt file.

```bash
# In ralph.conf:
HARNESS="custom"
CUSTOM_CMD="my-agent run --file {PROMPT_FILE} --auto-approve"

# Usage
./loop.sh
```

**Requirements:**
- Must accept prompt via file or stdin
- Must exit with code 0 on success
- Must modify files in working directory
- Should support git operations

**Example custom commands:**

```bash
# Aider
CUSTOM_CMD="aider --file {PROMPT_FILE} --yes"

# Continue
CUSTOM_CMD="continue --prompt-file {PROMPT_FILE}"

# Custom wrapper
CUSTOM_CMD="./my-wrapper.sh {PROMPT_FILE}"
```

---

## Comparison Matrix

| Feature | Claude Code | OpenCode | Codex | Custom |
|---------|-------------|----------|-------|--------|
| Subagents | Yes (Task) | No | No | Depends |
| Tool permissions | Fine-grained | Basic | Approval modes | Depends |
| Extended thinking | Yes | No | o1 only | Depends |
| Model flexibility | Claude only | xAI, OpenAI, Anthropic, Google, etc. | OpenAI only | Any |
| Loop mode | subprocess | server (HTTP API) | subprocess | Depends |
| Sandbox support | Yes | Basic | Yes | Depends |

## Recommendation

1. **Start with Claude Code** - Best agentic capabilities, native subagents
2. **Use OpenCode** for non-Claude models (xAI Grok, GPT-4o, Gemini) — use server mode
3. **Use Codex with o1** for complex reasoning tasks
4. **Custom** for specialized setups or proprietary tools

## Configuration

All harnesses are configured via `ralph.conf`:

```bash
HARNESS="claude"           # Which CLI
MODEL="gpt-4"              # Model (if needed)
CUSTOM_CMD=""              # Custom command template
ALLOW_SUBTASKS=true        # Enable Task tool (Claude only)
```

Or via command line:

```bash
./loop.sh --harness opencode --model gpt-4
./loop.sh --harness claude --allow-subtasks
```
