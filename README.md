# claude_skills

Personal skill bundles for Claude Code, managed with [skm](https://github.com/pyrex41/skill-manager).

## Setup

1. Install skm
2. Add this repo as a source:
   ```
   skm source add ~/claude_skills
   ```
   Or clone and point to it:
   ```
   skm source add https://github.com/pyrex41/claude_skills
   ```
3. Install a bundle:
   ```
   skm add fg
   ```

## Repo structure

Each top-level directory is a bundle. Bundles can contain any combination of:

```
bundle-name/
  skills/      # Slash-command skills
  agents/      # Agent definitions
  commands/    # Commands
  rules/       # Rules
```

The `skills/` directory at the root is a special case — it holds standalone skill bundles (like `gr-plan-review`) that use the Anthropic `skills/{name}/SKILL.md` format.

## Adding a new bundle

1. Create a directory at the repo root:
   ```
   mkdir -p my-bundle/commands
   ```
2. Add `.md` files to the appropriate subdirectories (`skills/`, `agents/`, `commands/`, `rules/`).
3. Register it in `skm.toml`:
   ```toml
   [[bundles]]
   name = "my-bundle"
   path = "my-bundle"
   ```
4. Install it:
   ```
   skm add my-bundle
   ```

## Why skm.toml?

This repo has a top-level `skills/` directory which would normally cause skm to treat the entire repo as an Anthropic-format skill source, hiding the individual bundle directories. The `skm.toml` manifest overrides that auto-detection and explicitly declares each bundle.
