#!/bin/bash
# Ralph Wiggum Outer Loop
# Runs Claude in a loop with fresh context each iteration

set -e

# Configuration
PROMPT_FILE="${PROMPT_FILE:-PROMPT.md}"
MAX_ITERATIONS="${MAX_ITERATIONS:-100}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-5}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

iteration=0

echo -e "${GREEN}Starting Ralph loop with ${PROMPT_FILE}${NC}"
echo -e "${YELLOW}Max iterations: ${MAX_ITERATIONS}${NC}"
echo ""

while [ $iteration -lt $MAX_ITERATIONS ]; do
    iteration=$((iteration + 1))
    echo -e "${GREEN}=== Iteration ${iteration} ===${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S')"

    # Run Claude with the prompt
    # Adjust flags based on your Claude CLI setup
    if ! cat "$PROMPT_FILE" | claude --dangerously-skip-permissions; then
        echo -e "${RED}Claude exited with error${NC}"
        echo "Sleeping before retry..."
        sleep "$SLEEP_BETWEEN"
        continue
    fi

    # Push changes if any
    if [ -n "$(git status --porcelain)" ]; then
        echo -e "${YELLOW}Pushing changes...${NC}"
        git push || echo -e "${RED}Push failed, continuing...${NC}"
    else
        echo "No changes to push"
    fi

    echo ""
    echo -e "${GREEN}Iteration ${iteration} complete${NC}"
    echo "Sleeping ${SLEEP_BETWEEN}s before next iteration..."
    sleep "$SLEEP_BETWEEN"
done

echo -e "${YELLOW}Reached max iterations (${MAX_ITERATIONS})${NC}"
