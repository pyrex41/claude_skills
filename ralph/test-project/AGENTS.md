# AGENTS.md - Test CLI Project

## Project Overview

A simple CLI tool that converts markdown files to HTML with syntax highlighting.

## Tech Stack

- Language: TypeScript
- Runtime: Node.js 20+
- Build: tsup
- Test: Vitest
- Key dependencies: marked, shiki

## Directory Structure

```
src/
├── index.ts        # CLI entry point
├── converter.ts    # Markdown conversion logic
└── highlighter.ts  # Syntax highlighting
tests/
└── *.test.ts       # Test files mirror src/
```

## Validation Commands

- **Build**: `npm run build`
- **Test**: `npm run test`
- **Lint**: `npm run lint`
- **Type check**: `npm run typecheck`
- **Full check**: `npm run typecheck && npm run lint && npm run test`

Run full check before every commit. All must pass.

## Conventions

### Code Style
- Use explicit return types on exported functions
- Prefer async/await over promises
- Use named exports, not default exports

### Patterns
- Errors: throw typed Error subclasses
- Logging: use debug package with namespace
- Config: environment variables via dotenv

### Testing
- Test files: `*.test.ts` next to source
- Use describe/it blocks
- Mock file system operations

## Subagent Guidelines

- Search/analysis: up to 50 parallel Sonnet subagents
- Implementation: up to 3 parallel Sonnet subagents
- Validation: exactly 1 Sonnet subagent, sequential steps

Never parallelize test execution.

## Guardrails

- Never modify package-lock.json manually
- Never commit .env files
- Always run typecheck before committing
