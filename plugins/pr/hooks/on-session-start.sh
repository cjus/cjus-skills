#!/bin/bash
# Hook: SessionStart — load the current branch's PR context into the session.
#
# Stdout goes straight into the model's context. Session sources are startup,
# resume, clear and compact; after a compaction this rehydrates the branch state
# so the successor does not resume blind.
#
# Convention: a per-branch folder at <changelogRoot>/<branch-slug>/, where the
# slug is the branch name minus the configured branch prefix. See
# reference/handoff-docs.md. There is no project-pointer file: the branch IS the
# pointer, so a worktree can never rehydrate another branch's context.

INPUT=$(cat)
SOURCE=$(printf '%s' "$INPUT" | grep -o '"source":"[^"]*"' | cut -d'"' -f4)
SOURCE=${SOURCE:-startup}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
[[ -n "$CURRENT_BRANCH" ]] || exit 0

# The default branch carries no per-branch folder, so there is nothing to load.
DEFAULT_BRANCH=$(git -C "$PROJECT_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
DEFAULT_BRANCH="${DEFAULT_BRANCH#origin/}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
[[ "$CURRENT_BRANCH" == "$DEFAULT_BRANCH" || "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]] && exit 0

# Config lives at the MAIN checkout's root, which is not $PROJECT_DIR inside a
# linked worktree. Defaults apply when it or jq is absent.
BRANCH_PREFIX="feature/"
CHANGELOG_ROOT="changelog"

COMMON=$(git -C "$PROJECT_DIR" rev-parse --git-common-dir 2>/dev/null)
if [[ -n "$COMMON" ]]; then
  [[ "$COMMON" == /* ]] || COMMON="${PROJECT_DIR}/${COMMON}"
  CONFIG="$(dirname "$COMMON")/.claude/pr-config.json"
  if [[ -f "$CONFIG" ]] && command -v jq >/dev/null 2>&1; then
    v=$(jq -r '.branchPrefix // "feature/"' "$CONFIG" 2>/dev/null) && BRANCH_PREFIX="$v"
    v=$(jq -r '.docs.changelogRoot // "changelog"' "$CONFIG" 2>/dev/null) && CHANGELOG_ROOT="$v"
  fi
fi

[[ -n "$CHANGELOG_ROOT" && "$CHANGELOG_ROOT" != "null" ]] || exit 0

BRANCH_SLUG="${CURRENT_BRANCH#"$BRANCH_PREFIX"}"
CHANGELOG_DIR="${PROJECT_DIR}/${CHANGELOG_ROOT}/${BRANCH_SLUG}"

# No folder for this branch, e.g. one created without /pr:start. Nothing to load.
[[ -d "$CHANGELOG_DIR" ]] || exit 0

PR_SUMMARIES=$(ls -t "$CHANGELOG_DIR"/pr-summary-*.md 2>/dev/null)

if [[ "$SOURCE" == "compact" ]]; then
  echo "=== REHYDRATING CONTEXT AFTER COMPACTING ==="
  # Leave a trace in the changelog so the operator can confirm the hook fired.
  if [[ -f "$CHANGELOG_DIR/CHANGELOG.md" ]]; then
    {
      echo ""
      echo "## $(date '+%Y-%m-%d %H:%M:%S')"
      echo ""
      echo "**Context rehydrated after compacting**"
      echo ""
      echo "---"
    } >> "$CHANGELOG_DIR/CHANGELOG.md"
  fi
else
  echo "=== CURRENT PR CONTEXT ==="
fi

echo "Branch: ${CURRENT_BRANCH}"
echo "Session source: $SOURCE"
echo ""

echo "### Files in the branch folder:"
ls -1 "$CHANGELOG_DIR" 2>/dev/null | while read -r file; do
  echo "- $file"
done
echo ""

if [[ -n "$PR_SUMMARIES" ]]; then
  # A summary exists, so it is the most condensed account of the branch and is
  # loaded INSTEAD of the plan. /pr:precompact knows this and appends a pointer
  # back to the plan's resume section when a summary is present.
  for summary in $PR_SUMMARIES; do
    echo "### $(basename "$summary")"
    echo '```'
    cat "$summary"
    echo '```'
    echo ""
  done
else
  if [[ -f "$CHANGELOG_DIR/PLAN.md" ]]; then
    echo "### PLAN.md"
    echo '```'
    cat "$CHANGELOG_DIR/PLAN.md"
    echo '```'
    echo ""
  fi

  if [[ -f "$CHANGELOG_DIR/CHANGELOG.md" ]]; then
    LINES=$(wc -l < "$CHANGELOG_DIR/CHANGELOG.md")
    echo "### CHANGELOG.md"
    echo '```'
    if [[ $LINES -gt 100 ]]; then
      echo "# (Showing last 100 of $LINES lines)"
      echo ""
      tail -100 "$CHANGELOG_DIR/CHANGELOG.md"
    else
      cat "$CHANGELOG_DIR/CHANGELOG.md"
    fi
    echo '```'
    echo ""
  fi
fi

echo "=== END PR CONTEXT ==="
exit 0
