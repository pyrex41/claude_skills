---
name: ralph-loop
description: Use when setting up an autonomous development loop (Ralph Wiggum method) for any project. Covers scaffolding the loop scripts, stream display, stop file mechanism, prompt structure, and exit criteria. Use this when a user wants to set up unattended or semi-supervised agentic iteration on a codebase.
---

# Ralph Loop: Autonomous Development via Bash Iteration

## 1. What It Is

A bash loop that feeds prompts to a CLI agent repeatedly. State persists through files (git + markdown), not LLM context. Each iteration starts fresh to avoid context rot.

```bash
while :; do
  claude --output-format stream-json -p "$(cat PROMPT.md)" | python3 stream_display.py
done
```

The agent does ONE task per iteration, commits, updates the plan, and exits. The loop restarts with clean context. The plan file is the source of truth.

## 2. Core Invariants

**1. One task per iteration**

The agent picks one task, implements it, validates, commits, and exits. If it does two tasks in one iteration, context degrades and failures are harder to isolate.

**2. State lives in files, not in the LLM**

Git commits, `IMPLEMENTATION_PLAN.md`, and source code are the only persistent state. The agent reads them fresh each time. There is no conversation history between iterations.

**3. Every iteration exits**

Success exits. Failure exits. Empty queue exits. The loop handles restarts — individual iterations do not retry.

**4. The loop always stops**

Two hard stop conditions:
- Max iterations (always enforced, default 30)
- Stop file (`ralph/.stop`) — the agent writes it when there's nothing left to do

There is no "run forever" mode.

## 3. Scaffolding a New Project

### Minimum viable setup

```
your-project/
└── ralph/
    ├── loop.sh                # The loop — copy as-is
    ├── supervised.sh          # Human-approval variant — copy as-is
    ├── stream_display.py      # Stream display — copy as-is (or write your own)
    ├── PROMPT_plan.md         # Planning mode instructions — write per project
    ├── PROMPT_build.md        # Build mode instructions — write per project
    ├── AGENTS.md              # Build/test commands, conventions — write per project
    └── IMPLEMENTATION_PLAN.md # Task state — seed with section headers
```

### What to copy unchanged

`loop.sh`, `supervised.sh`, `stream_display.py`. These discover paths relative to themselves (`SCRIPT_DIR`, `PROJECT_ROOT`) and contain no project-specific logic.

### What to write per project

**AGENTS.md** — The reference card agents read every iteration:
- Build command
- Test command
- Directory structure
- Code style conventions
- Git commit format

**PROMPT_plan.md** — Planning mode instructions:
- Where specs/requirements live
- How to do gap analysis
- Update `IMPLEMENTATION_PLAN.md` only — no code
- When to write the stop file

**PROMPT_build.md** — Build mode instructions:
- Pick ONE task from "Next Up"
- Implement, test, commit
- Mark task complete in the plan
- When to write the stop file

**IMPLEMENTATION_PLAN.md** — Seed with:
```markdown
## Completed
## In Progress
## Next Up
## Blocked / Needs Human Input
```

## 4. The Stop File

The stop file (`ralph/.stop`) is how the agent tells the loop to stop. The loop checks for it before each iteration.

### How it works

The agent writes a reason to the file:
```bash
echo "no tasks remaining" > ralph/.stop
echo "planning complete - all specs covered" > ralph/.stop
echo "all tasks blocked" > ralph/.stop
```

The loop reads the contents as a log message, deletes the file, and breaks. On startup, the loop also cleans up any stale stop file from a previous run.

### When the agent should write it

- **Build mode:** No tasks in "Next Up" (queue empty). All remaining tasks are blocked.
- **Plan mode:** All specs are covered, no new gaps found.

### Your prompts must include this

Every prompt file needs a "Stopping the Loop" section that tells the agent exactly when and how to write the stop file. If you omit this, the loop will keep restarting iterations that immediately exit — burning API calls doing nothing.

## 5. Exit Criteria in Prompts

Each iteration must exit cleanly so the next one starts with fresh context. If your prompts don't make exit conditions explicit, agents will either:
- Spin within a single iteration doing multiple tasks (burning context)
- Exit before committing state (next iteration redoes the same work)

### The pattern

Every prompt should follow this sequence:
1. Do the work (one task / one planning pass)
2. Validate (tests pass / plan is coherent)
3. Commit state to files (git commit / update plan markdown)
4. If nothing left to do → write `ralph/.stop` with a reason
5. Exit

### Every code path ends with "exit"

- Task done, tests pass → commit, exit
- Can't fix test after N attempts → mark blocked in plan, exit
- No tasks in queue → write stop file, exit
- Stuck or confused → add blocker note to plan, exit

The loop handles retries. Individual iterations do not.

### Example build prompt exit section

```markdown
## Stopping the Loop

Write a reason to `ralph/.stop` to signal the loop should not start another iteration:
- No tasks left in "Next Up" → `echo "no tasks remaining" > ralph/.stop`
- All tasks blocked / need human input → `echo "all tasks blocked" > ralph/.stop`

When your ONE task is complete and committed, exit. The loop handles the next task.
```

### Example plan prompt exit section

```markdown
## Stopping the Loop

If there is nothing meaningful left to plan (all specs are covered, no new gaps found):
- `echo "planning complete - all specs covered" > ralph/.stop`

When done, simply exit. The loop will restart for the next iteration.
```

## 6. loop.sh

The main orchestration script. Supports multiple CLI backends.

### Usage

```bash
./ralph/loop.sh [plan|build] [options]

Options:
  -n, --iterations N    Max iterations (default: 30)
  -m, --model MODEL     Model override (default: opus 4.5)
  -c, --cli CLI         CLI tool: claude|cursor|opencode (default: cursor)
  --allow-subtasks      Enable Task tool for sub-agents (build mode)
  --dump FILE           Dump raw stream JSON for debugging
```

### Stop conditions (checked every iteration)

1. Stop file exists (`ralph/.stop`) → log reason, delete file, break
2. Iteration count exceeds max → break
3. Ctrl-C → break

### Key implementation details

- Cleans up stale `.stop` file on startup
- Checks stop file both before each iteration AND immediately after (skips the sleep)
- Failures don't stop the loop — exit codes are logged but iteration continues
- `SCRIPT_DIR` / `PROJECT_ROOT` are discovered from the script's own location
- Prompt content is read once at startup via `cat "$PROMPT_FILE"`

### CLI backends

| CLI | Binary | Stream args | Permissions |
|-----|--------|-------------|-------------|
| claude | `claude` | `--output-format stream-json --verbose --include-partial-messages` | `--dangerously-skip-permissions` (plan) or `--allowedTools` (build) |
| cursor | `cursor-agent` | `--output-format stream-json --stream-partial-output` | `--force` |
| opencode | `opencode` | n/a (no stream display) | via config |

## 7. Stream Display

Raw CLI output is streaming JSON — not human-readable. The display script sits between the CLI and your terminal as a stdin filter.

### Architecture

```bash
$CLI --output-format stream-json -p "$PROMPT" | python3 stream_display.py --iteration N --mode MODE
```

The display reads JSON lines from stdin and renders:
- Tool calls (always visible, color-coded by type)
- Agent text output (togglable with `[v]` key)
- Git status diff (before/after each iteration, shown in footer)
- Elapsed time and tool count

### Event types it handles

| Event type | What it does |
|-----------|--------------|
| `assistant` | Walks `message.content[]`, prints `text` blocks, extracts `tool_use` blocks |
| `content_block_start` | Begins accumulating tool input for streaming mode |
| `content_block_delta` | Prints `text_delta` inline, accumulates `input_json_delta` for tools |
| `content_block_stop` | Parses accumulated tool input JSON, prints tool name + key arg |
| `tool_call` | Fallback for CLIs that send tool events separately |

### Deduplication

Per-block dedup tracks by `(message_id, content_index)`. When a new message ID appears, trackers reset. This prevents reprinting text when partial messages arrive (the CLI sends the full content array each time, growing incrementally).

### Tool colors

| Color | Tools |
|-------|-------|
| Blue | Read, Glob, Grep, LS |
| Yellow | Edit, Write, NotebookEdit |
| Green | Bash |
| Magenta | Task |
| Cyan | WebFetch, WebSearch |

### The `[v]` toggle

A background thread reads keypresses from `/dev/tty` via termios cbreak mode. Press `v` to collapse text — only tool calls remain visible, with a spinner status bar showing elapsed time and tool count. Press `v` again to expand. Falls back gracefully if `/dev/tty` is unavailable.

### Debugging

If tools show as `?` or text is missing, dump the raw JSON:

```bash
./ralph/loop.sh build --dump /tmp/stream.jsonl
cat /tmp/stream.jsonl | python3 -m json.tool | less
```

### Writing your own display

The included `stream_display.py` is ~480 lines. A minimal display only needs:

1. Read lines from stdin
2. Parse each line as JSON
3. Handle `assistant` events: walk `message.content[]`, print `text` blocks, extract `tool_use` blocks
4. Handle `content_block_delta`: print `text_delta`, accumulate `input_json_delta`
5. Handle `content_block_stop`: parse accumulated tool JSON, print tool name + key arg

That's ~80 lines in any language. Everything else (colors, spinners, toggle, git snapshots, dedup) is polish. You could write it in bash with `jq`, Node, Go, whatever fits.

The key point: **pipe `--output-format stream-json` into your display**. Don't parse terminal escape codes from the CLI's normal output.

## 8. supervised.sh

Same loop but pauses after each iteration for human review:

```
Options:
  [Enter] Continue to next iteration
  [r]     Review changes (git diff)
  [c]     Commit pending changes
  [q]     Quit loop
```

Also checks the stop file. Useful for learning the loop's behavior or for safety-critical work.

## 9. Anti-patterns

**No "run forever" mode.** Always set a max iteration cap. Default is 30.

**Don't let the agent retry within an iteration.** If tests fail 3 times, mark blocked and exit. The loop can retry next iteration with fresh context, which often works better than grinding in degraded context.

**Don't skip the state commit.** If the agent exits without committing to git or updating the plan markdown, the next iteration starts with stale state and redoes the same work.

**Don't let the agent do multiple tasks.** "ONE task per iteration" must be explicit in the prompt. Agents will happily keep working if you don't tell them to stop.

**Don't parse CLI terminal output.** Always use `--output-format stream-json` and pipe it. The terminal output has escape codes, spinners, and formatting that changes between versions.

## 10. References

- [ghuntley/how-to-ralph-wiggum](https://github.com/ghuntley/how-to-ralph-wiggum)
- [Ralph Wiggum Playbook](https://paddo.dev/blog/ralph-wiggum-playbook/)
- [ghuntley.com/ralph](https://ghuntley.com/ralph/)
