---
date: 2026-02-02T23:13:49Z
researcher: reuben
git_commit: 97131294162e58ba7ead4577036d4d5a330b1227
branch: master
repository: claude_skills
topic: "How to write Claude Code skills: standard format and best practices"
tags: [research, skills, claude-code, agent-skills, best-practices]
status: complete
last_updated: 2026-02-02
last_updated_by: reuben
---

# Research: How to Write Claude Code Skills - Standard Format and Best Practices

**Date**: 2026-02-02T23:13:49Z
**Researcher**: reuben
**Git Commit**: 97131294162e58ba7ead4577036d4d5a330b1227
**Branch**: master
**Repository**: claude_skills

## Research Question

How to write skills for Claude Code - both the standard format and best practices for creating effective, well-designed skills.

## Summary

Skills are instruction files (`SKILL.md`) that extend Claude's capabilities. They follow the [Agent Skills](https://agentskills.io) open standard, which works across 25+ AI tools including Claude Code, Cursor, VS Code, and GitHub Copilot. Skills use **progressive disclosure** to load context on-demand: metadata loads at startup, full instructions load when activated, and resources load only when needed.

The key to writing good skills is **conciseness** - context window is a shared resource. Write instructions assuming Claude is already smart, only adding what it doesn't know. Use appropriate freedom levels (text vs pseudocode vs exact scripts) based on task fragility.

---

## Part 1: The Standard Format

### Directory Structure

```
skill-name/
├── SKILL.md           # Required: main instructions
├── scripts/           # Optional: executable code
├── references/        # Optional: documentation loaded on-demand
└── assets/            # Optional: templates, images, data
```

### SKILL.md Format

Every skill has YAML frontmatter followed by Markdown content:

```yaml
---
name: skill-name
description: What this skill does and when to use it
---

Your markdown instructions here...
```

### Required Fields

Only the `SKILL.md` file itself is required. Everything else is optional.

### Recommended Fields

| Field | Description |
|-------|-------------|
| `name` | Display name (1-64 chars, lowercase alphanumeric + hyphens). Defaults to directory name |
| `description` | What it does AND when to use it (1-1024 chars). Claude uses this to decide when to activate |

### Optional Fields

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `argument-hint` | string | Hint for autocomplete (e.g., `[issue-number]`, `[filename]`) | None |
| `disable-model-invocation` | boolean | Prevent Claude from auto-loading; manual `/skill` only | `false` |
| `user-invocable` | boolean | Hide from `/` menu if `false` (background knowledge) | `true` |
| `allowed-tools` | list | Tools Claude can use without permission prompts | None |
| `model` | string | Model to use when skill is active | Default |
| `context` | string | Set to `fork` to run in a forked subagent | inline |
| `agent` | string | Subagent type when `context: fork` (e.g., `Explore`, `Plan`) | `general-purpose` |
| `hooks` | object | Hooks scoped to skill lifecycle | None |

### Storage Locations (Determines Scope)

| Location | Path | Applies to | Priority |
|----------|------|------------|----------|
| Enterprise | Managed settings | All org users | Highest |
| Personal | `~/.claude/skills/<name>/SKILL.md` | All your projects | High |
| Project | `.claude/skills/<name>/SKILL.md` | This project only | Medium |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | Where plugin enabled | Special |

When skills share the same name: **enterprise > personal > project**

---

## Part 2: Best Practices

### Core Principle: Conciseness is Key

> "Context window is a public good shared with system prompt, conversation history, and other skills."

**Challenge every piece of information**: Does Claude really need this explanation?

**Bad** - Over-explaining:
```markdown
# How to Process Files
Files are stored on disk. When you need to process a file, you first need to read
it into memory. Files can be text files or binary files. Text files contain
human-readable characters while binary files contain raw bytes...
```

**Good** - Concise:
```markdown
# File Processing
1. Read file with appropriate encoding
2. Parse according to format
3. Validate structure before modifications
```

### Set Appropriate Degrees of Freedom

Match instruction specificity to task fragility:

| Freedom Level | Format | When to Use |
|---------------|--------|-------------|
| **High** | Text instructions | Multiple valid approaches, context-dependent |
| **Medium** | Pseudocode/templates | Preferred pattern exists, some variation OK |
| **Low** | Exact scripts | Operations are fragile, consistency critical |

**Example - High Freedom** (text):
```markdown
Create a summary of the document that captures the key points.
```

**Example - Medium Freedom** (template):
```markdown
Generate output in this format:
- **Summary**: [1-2 sentences]
- **Key Points**: [bullet list]
- **Action Items**: [if any]
```

**Example - Low Freedom** (exact script):
```markdown
Run exactly: `python scripts/process.py --input $FILE --validate`
```

### Writing Effective Descriptions

**Always use third person** - descriptions are injected into system prompts:

```yaml
# Good
description: Processes Excel files and generates summary reports

# Avoid
description: I can help you process Excel files
```

**Be specific and include triggers**:

```yaml
description: >
  Extract text and tables from PDF files, fill forms, merge documents.
  Use when working with PDF files or when the user mentions PDFs,
  forms, or document extraction.
```

### Naming Conventions

**Recommended**: Gerund form (verb + -ing)
- `processing-pdfs`
- `analyzing-spreadsheets`
- `managing-databases`

**Avoid**:
- Vague names: `helper`, `utils`, `tools`
- Reserved words: `anthropic-*`, `claude-*`

### Progressive Disclosure Patterns

Keep `SKILL.md` under 500 lines. Move detailed content to separate files.

**Pattern 1: High-level guide with references**
```markdown
# PDF Processing

## Quick Start
[Basic instructions - 50 lines]

## Advanced Features
**Form filling**: See [FORMS.md](FORMS.md)
**API reference**: See [REFERENCE.md](REFERENCE.md)
```

**Pattern 2: Domain-specific organization**
```
bigquery-skill/
├── SKILL.md (overview and navigation)
└── reference/
    ├── finance.md
    ├── sales.md
    └── product.md
```

**Pattern 3: Conditional details**
```markdown
## Basic Usage
[Simple instructions]

## Advanced (only if needed)
For complex scenarios, see [advanced.md](advanced.md)
```

**Important**: Keep file references **one level deep** from SKILL.md - avoid nested references.

### Invocation Control Patterns

| Use Case | Frontmatter | Effect |
|----------|-------------|--------|
| Default (recommended) | (none) | User and Claude can invoke |
| Manual-only workflows | `disable-model-invocation: true` | Only user can invoke with `/skill` |
| Background knowledge | `user-invocable: false` | Only Claude can invoke when relevant |

**Use `disable-model-invocation: true`** for:
- Tasks with side effects (`/deploy`, `/send-slack`)
- Destructive operations
- Workflows needing explicit user intent

**Use `user-invocable: false`** for:
- Coding conventions and style guides
- API patterns Claude should follow automatically
- Context that isn't actionable as a command

### Working with Arguments

```yaml
---
name: fix-issue
description: Fix a GitHub issue by number
argument-hint: [issue-number]
---

Fix GitHub issue $ARGUMENTS following our coding standards.

1. Read issue: `gh issue view $1`
2. Understand requirements
3. Implement fix
4. Write tests
5. Create commit
```

- `$ARGUMENTS` - All arguments as single string
- `$ARGUMENTS[N]` or `$N` - Specific positional argument (1-indexed)
- If `$ARGUMENTS` isn't present, arguments auto-append as `ARGUMENTS: <value>`

### Dynamic Context Injection

Use `` !`command` `` to run shell commands before content reaches Claude:

```yaml
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
allowed-tools: Bash(gh *)
---

## Pull Request Context
- PR diff: !`gh pr diff`
- PR comments: !`gh pr view --comments`
- Changed files: !`gh pr diff --name-only`

## Your Task
Summarize this pull request...
```

The command output replaces the placeholder **before** Claude sees it.

### Workflows and Verification

**Use checklists for complex workflows**:

````markdown
Copy this checklist and track your progress:
```
Progress:
- [ ] Step 1: Read all source documents
- [ ] Step 2: Identify key themes
- [ ] Step 3: Cross-reference claims
```
````

**Implement validation loops**:
```markdown
1. Execute task
2. Validate output against criteria
3. If validation fails, fix and repeat
4. Only proceed when validation passes
```

### Bundling Scripts

Include executable scripts for reliable, repeatable operations:

```
skill-name/
├── SKILL.md
└── scripts/
    ├── validate.py
    ├── process.sh
    └── transform.js
```

Reference in SKILL.md:
```yaml
allowed-tools: Bash(python *)
---

Run validation:
```bash
python ~/.claude/skills/skill-name/scripts/validate.py $FILE
```
```

### Subagent Execution

Run skills in isolated context:

```yaml
---
name: explore-codebase
context: fork
agent: Explore
---

Explore the codebase to find...
```

Only use for skills with **explicit task instructions** (not guidelines).

---

## Part 3: Anti-Patterns to Avoid

### Don't Over-Explain

**Bad**:
```markdown
# Understanding Files
Before we begin, let me explain what files are. Files are units of data
stored on your computer's hard drive or solid-state drive. They can contain
text, images, code, or any other type of information...
```

**Good**:
```markdown
# File Processing
When modifying files:
1. Validate format before changes
2. Preserve original encoding
3. Verify output integrity
```

### Don't Nest References Deeply

**Bad**:
```
SKILL.md → reference.md → details.md → examples.md
```

**Good**:
```
SKILL.md → reference.md (with inline examples)
```

### Don't Include Time-Sensitive Info

**Bad**:
```markdown
As of January 2024, the API uses v3...
```

**Good**:
```markdown
## Current API
Use the v3 API endpoint...

## Legacy Patterns (deprecated)
If you encounter v2 patterns, migrate to v3...
```

### Don't Offer Too Many Options Without Defaults

**Bad**:
```markdown
You can use approach A, B, C, D, or E depending on the situation.
```

**Good**:
```markdown
Use approach A (recommended for most cases).

For special situations:
- Approach B: [specific scenario]
- Approach C: [specific scenario]
```

### Don't Add Unnecessary Files

**Avoid creating**:
- `README.md` (use SKILL.md)
- `INSTALLATION.md` (keep in SKILL.md if needed)
- `CHANGELOG.md`
- Duplicate documentation

---

## Part 4: Example Skills

### Simple Reference Skill

```yaml
---
name: api-conventions
description: API design patterns for this codebase. Applied when writing API endpoints.
---

When writing API endpoints:
- Use RESTful naming conventions
- Return consistent error format: `{error: string, code: number}`
- Include request validation
- Add rate limiting headers
```

### Task Skill with Arguments

```yaml
---
name: fix-issue
description: Fix a GitHub issue
disable-model-invocation: true
argument-hint: [issue-number]
---

Fix GitHub issue $ARGUMENTS:

1. Read issue: `gh issue view $1`
2. Understand requirements
3. Implement the fix
4. Write tests covering the fix
5. Create commit with message referencing issue
```

### Skill with Progressive Disclosure

```yaml
---
name: database-operations
description: Database schema changes and migrations. Use when modifying database structure.
---

# Database Operations

## Quick Reference
- Schema changes require migration files
- Always include rollback logic
- Test on staging first

## Detailed Procedures
**Creating migrations**: See [migrations.md](migrations.md)
**Schema conventions**: See [schema.md](schema.md)
**Testing approach**: See [testing.md](testing.md)
```

### Skill with Bundled Scripts

```yaml
---
name: pptx
description: PPTX Creation, Editing, and Analysis
allowed-tools: Bash(python *), Bash(node *)
---

# PowerPoint Operations

## Reading Content
```bash
python -m markitdown path-to-file.pptx
```

## Creating Presentations
Use the html2pptx library. See [html2pptx.md](html2pptx.md) for details.

## Editing Existing Files
OOXML workflow: Unpack → Edit XML → Validate → Pack
See [ooxml.md](ooxml.md) for XML schemas and examples.
```

### Minimal Effective Skill

```yaml
---
name: interview
description: Interview user in-depth to create a detailed spec
argument-hint: [instructions]
allowed-tools: AskUserQuestion, Write
---

Follow the user instructions and interview me in detail using the AskUserQuestion
tool about literally anything: technical implementation, UI & UX, concerns,
tradeoffs, etc. but make sure the questions are not obvious. Be very in-depth
and continue interviewing me continually until it's complete. Then, write the
spec to a file.

<instructions>$ARGUMENTS</instructions>
```

---

## Part 5: Development Workflow

### Evaluation-Driven Development

1. **Identify gaps**: Run agent on tasks WITHOUT a skill, document failures
2. **Create evaluations**: Build 3+ test scenarios
3. **Establish baseline**: Measure performance without skill
4. **Write minimal instructions**: Just enough to pass evaluations
5. **Iterate**: Test, compare to baseline, refine

### Iterative Development with Claude

1. Complete a task without a skill (Claude A helps you)
2. Notice what context you repeatedly provide
3. Ask Claude A to create a skill capturing that pattern
4. Test the skill with Claude B (fresh instance) on similar tasks
5. Observe Claude B's behavior and bring insights back to Claude A
6. Iterate based on real usage, not assumptions

### Testing Considerations

- Test with all target models (Haiku, Sonnet, Opus)
- What works for Opus might need more detail for Haiku
- Test both manual invocation (`/skill`) and automatic triggering

---

## Code References

- Official documentation: https://code.claude.com/docs/en/skills
- Agent Skills specification: https://agentskills.io/specification
- Anthropic example skills: https://github.com/anthropics/skills
- PPTX skill (complex example): https://github.com/anthropics/skills/tree/main/skills/pptx
- Skill creator skill: https://github.com/anthropics/skills/tree/main/skills/skill-creator

## Related Research

- Agent Skills standard: https://agentskills.io
- Best practices documentation: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices

## Open Questions

- What's the optimal balance between instruction detail and model capability for different tasks?
- How to effectively test skills across the full range of possible inputs?
- Best practices for versioning skills as Claude's capabilities evolve?
