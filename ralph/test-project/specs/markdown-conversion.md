# Markdown Conversion

## Job to Be Done

When I have markdown files, I want to convert them to HTML with syntax-highlighted code blocks, so I can publish them as web pages.

## Functional Requirements

- [ ] FR-1: Accept markdown file path as CLI argument
- [ ] FR-2: Parse markdown using standard CommonMark spec
- [ ] FR-3: Detect code block language from fence info string
- [ ] FR-4: Apply syntax highlighting using shiki
- [ ] FR-5: Output HTML to stdout or specified output file
- [ ] FR-6: Support `--theme` flag for highlight theme selection

## Non-Functional Requirements

- [ ] NFR-1: Process files under 1MB in less than 500ms
- [ ] NFR-2: Exit with code 1 on any error, code 0 on success
- [ ] NFR-3: Provide helpful error messages for common failures

## Acceptance Criteria

1. Given a valid markdown file, when converted, then outputs valid HTML
2. Given a code block with `ts` language, when converted, then includes highlighted spans
3. Given `--theme dracula`, when converted, then uses Dracula color scheme
4. Given a non-existent file path, when run, then exits with code 1 and error message
5. Given `--output out.html`, when converted, then writes to out.html instead of stdout

## Out of Scope

- Watch mode / live reload
- Multiple file batch processing
- Custom CSS injection

## Dependencies

- Requires: marked (markdown parser), shiki (syntax highlighter)
