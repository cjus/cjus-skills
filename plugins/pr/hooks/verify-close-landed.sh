#!/bin/bash
# Hook: Stop — refuse to end a /pr:close turn whose artifacts have not landed.
#
# /pr:close already says "End only when `git status --porcelain` reports clean".
# A close still once cleared every gate, reported success, and left four artifacts
# uncommitted anyway: the continuity entry, the PR summary, the review and the
# commit message, none of which reached the merged PR. A prose instruction is a
# behavioral expectation a long workflow can lose; a Stop hook is not.
#
# Verified against Claude Code by probing a scratch project rather than trusting
# the docs:
#   - a Stop hook forces a continuation by printing top-level
#     {"decision":"block","reason":"..."} on stdout.
#   - that IS honored under bypassPermissions. The PreToolUse trap, where
#     permissionDecision:"ask" is silently a no-op in non-prompting modes and is
#     why the main guard needs an ask/deny split, has NO analog here. One verdict
#     works in every mode.
#   - stop_hook_active flips to true on the forced continuation.
#   - the payload carries session_id, transcript_path, cwd, prompt_id,
#     permission_mode, hook_event_name, stop_hook_active, last_assistant_message
#     and NOTHING naming the active skill.
#
# That last point is why the sentinel exists. The hook cannot tell a /pr:close
# turn from any other turn, so without scoping it would demand a clean tree on
# every stop during ordinary development. /pr:close arms the sentinel at step 7
# and this hook clears it once the checks pass.
#
# Why step 7 and not step 0: every halt gate in /pr:close fires BEFORE step 7, so
# arming late means a halted close cannot strand the sentinel, and the one
# remaining legitimate pause (the default-branch stop) is never blocked. Between
# step 7 and the end there is no legitimate stop.
#
# Blast radius is bounded by design: stop_hook_active means this blocks AT MOST
# ONCE per turn. The block path deliberately leaves the sentinel armed, so a close
# abandoned after step 7 costs one extra turn PER TURN until someone runs
# --disarm (which every block message names) or the tree satisfies every check.
# Never a wedged session, but not a one-time cost either. /pr:close also clears a
# leftover sentinel at its start.
#
# Sentinel lives in `git rev-parse --git-dir`, which in a worktree is
# .git/worktrees/<name> — per-worktree, removed with the worktree, and OUTSIDE the
# work tree, so the sentinel can never dirty the git status it guards.
#
# Decision table:
#   stop_hook_active=true   -> exit 0 (already blocked once this turn)
#   no sentinel             -> exit 0 (no close in flight; the common case)
#   cwd is not a git repo   -> exit 0 (nothing to verify)
#   tree dirty / tip unpushed / a required artifact missing or untracked
#                           -> block, naming the offending paths
#   all checks pass         -> clear the sentinel, exit 0
#
# Also usable as a tiny CLI so /pr:close never has to spell the sentinel path:
# `--arm` at step 7, `--disarm` at step 0 and to abandon a close. Keeping the path
# in one place means the skill and the hook cannot drift apart, and it keeps the
# skill's allowed-tools off a bare `rm`.

SENTINEL_NAME="pr-close-active"

sentinel_path() {
  local dir
  dir=$(git rev-parse --git-dir 2>/dev/null) || return 1
  [[ -n "$dir" ]] || return 1
  [[ "$dir" == /* ]] || dir="${PWD}/${dir}"
  printf '%s/%s' "$dir" "$SENTINEL_NAME"
}

case "$1" in
  --arm | --disarm)
    SP=$(sentinel_path) || {
      echo "verify-close-landed: not a git repository" >&2
      exit 1
    }
    if [[ "$1" == "--arm" ]]; then
      : > "$SP" && echo "close sentinel armed: $SP"
    else
      rm -f "$SP" && echo "close sentinel cleared: $SP"
    fi
    exit 0
    ;;
esac

# A Stop hook is always fed a payload on stdin. A bare manual run is not, and
# would otherwise hang here with no output; --arm/--disarm return before this.
if [[ -t 0 ]]; then
  echo "verify-close-landed: Stop hook — expects a JSON payload on stdin." >&2
  echo "usage: verify-close-landed.sh [--arm | --disarm]" >&2
  exit 1
fi

INPUT=$(cat)

# Minimal extractors for the only two fields this hook reads, used when jq is
# absent. NOT a JSON parser: each handles one flat "key": value pair and assumes
# the value carries no escaped quote. That is true of both fields here (`cwd` is a
# path, `stop_hook_active` a bare boolean) and the payload is single-line, so the
# sed is line-oriented on purpose.
#
# These exist because the obvious fallback, defaulting CWD to $PWD, is wrong in
# the silent direction. A hook process's cwd is NOT the session's project dir, so
# the sentinel lookup lands in the wrong repo, finds nothing and exits 0. That is
# not a degraded check; it is no check at all, on exactly the turn the check
# exists for.
#
# Both forms below are BSD-sed-safe, and both alternatives cost a debugging pass
# to learn. `[a-z][a-z]*` rather than `\(true\|false\)`: BSD BRE has no
# alternation, and the alternation form does not error, it silently matches
# NOTHING, yielding an empty ACTIVE and a dropped loop guard. `| tail -1` rather
# than a `{p;q;}` block after the s///: that block is a GNU extension and BSD sed
# rejects it outright.
#
# Greedy `.*` means these take the LAST occurrence in the payload. Fine for the
# real fields; a hostile last_assistant_message quoting its own "cwd": could in
# principle shadow it. jq is the correct parser and is used whenever present.
json_string() {
  printf '%s' "$INPUT" |
    sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tail -1
}
json_bool() {
  printf '%s' "$INPUT" |
    sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*\([a-z][a-z]*\).*/\1/p' | tail -1
}

HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

if [[ "$HAVE_JQ" == "1" ]]; then
  ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
else
  # Degraded: the diagnosis narrows to static text (see the printf at the end),
  # but scoping and the loop guard both survive, because both come from the
  # payload rather than from jq.
  ACTIVE=$(json_bool stop_hook_active)
  CWD=$(json_string cwd)
fi

[[ "$ACTIVE" == "true" ]] || ACTIVE="false"

# Last resort only. CLAUDE_PROJECT_DIR is exported for hook commands and is the
# session's project dir; $PWD merely happens to be it sometimes, and is kept only
# so a hand-run from a repo root still does something sensible.
[[ -n "$CWD" ]] || CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

# Already forced one continuation this turn. Step aside so the agent can report.
[[ "$ACTIVE" == "true" ]] && exit 0

GIT_DIR=$(git -C "$CWD" rev-parse --git-dir 2>/dev/null) || exit 0
[[ -n "$GIT_DIR" ]] || exit 0
# rev-parse may return a relative path; resolve it against the repo.
[[ "$GIT_DIR" == /* ]] || GIT_DIR="${CWD}/${GIT_DIR}"

SENTINEL="${GIT_DIR}/${SENTINEL_NAME}"
[[ -f "$SENTINEL" ]] || exit 0

TOP=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)

# ---------------------------------------------------------------------- config
#
# The config lives at the MAIN checkout's root, which is not $TOP inside a linked
# worktree. Resolve it the same way every skill does. Defaults apply when the file
# is absent or jq is missing, so the hook still enforces the common case.

COMMON=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null)
if [[ -n "$COMMON" ]]; then
  [[ "$COMMON" == /* ]] || COMMON="${CWD}/${COMMON}"
  REPO_ROOT=$(dirname "$COMMON")
else
  REPO_ROOT="$TOP"
fi

CONFIG="${REPO_ROOT}/.claude/pr-config.json"

BRANCH_PREFIX="feature/"
CHANGELOG_ROOT="changelog"
CONTINUITY_ROOT="continuity"
REQUIRED="pr-summary continuity"
ENABLED="true"

if [[ "$HAVE_JQ" == "1" && -f "$CONFIG" ]]; then
  v=$(jq -r '.branchPrefix // "feature/"' "$CONFIG" 2>/dev/null) && BRANCH_PREFIX="$v"
  v=$(jq -r '.docs.changelogRoot // "changelog"' "$CONFIG" 2>/dev/null) && CHANGELOG_ROOT="$v"
  v=$(jq -r '.docs.continuityRoot // "continuity"' "$CONFIG" 2>/dev/null) && CONTINUITY_ROOT="$v"
  v=$(jq -r '(.closeGate.requiredArtifacts // ["pr-summary","continuity"]) | join(" ")' "$CONFIG" 2>/dev/null) && REQUIRED="$v"
  v=$(jq -r 'if .closeGate.enabled == false then "false" else "true" end' "$CONFIG" 2>/dev/null) && ENABLED="$v"
fi

# A disabled gate still clears the sentinel, so turning it off cannot leave a
# stale one blocking every later turn.
if [[ "$ENABLED" != "true" ]]; then
  rm -f "$SENTINEL"
  exit 0
fi

SLUG="${BRANCH#"$BRANCH_PREFIX"}"

PROBLEMS=""
add() { PROBLEMS="${PROBLEMS}
  - $1"; }

# 1. Working tree clean. Plain --porcelain on purpose: it reports UNTRACKED files
#    too, and the stranded artifacts in that incident were new untracked files.
#    With -uno it would have read clean.
DIRTY=$(git -C "$TOP" status --porcelain 2>/dev/null)
if [[ -n "$DIRTY" ]]; then
  add "Uncommitted changes ($(printf '%s\n' "$DIRTY" | wc -l | tr -d ' ') path(s)):"
  PROBLEMS="${PROBLEMS}
$(printf '%s\n' "$DIRTY" | sed 's/^/      /')"
fi

# 2. Branch tip pushed. No upstream means definitionally unpushed.
if git -C "$TOP" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  AHEAD=$(git -C "$TOP" rev-list --count '@{u}..HEAD' 2>/dev/null)
  [[ "$AHEAD" =~ ^[0-9]+$ ]] || AHEAD=0
  if [[ "$AHEAD" -gt 0 ]]; then
    add "Branch tip is $AHEAD commit(s) ahead of its upstream — not pushed."
  fi
else
  add "Branch '${BRANCH:-?}' has no upstream, so nothing has been pushed."
fi

# 3. The artifacts whose ABSENCE is silent. The tree-clean leg above catches every
#    artifact once it exists on disk; this is the backstop for "never written at
#    all". Newest wins: a re-close or a date boundary can leave two summaries, and
#    a tracked stale one must not satisfy the check for an untracked new one.
check_artifact() {
  local label="$1" path="$2"
  if [[ -z "$path" ]]; then
    add "No ${label} — that step's output never reached the branch."
  elif ! git -C "$TOP" ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    add "$(basename "$path") exists but is UNTRACKED."
  fi
}

if [[ -n "$SLUG" ]]; then
  for want in $REQUIRED; do
    case "$want" in
      pr-summary)
        [[ -n "$CHANGELOG_ROOT" && "$CHANGELOG_ROOT" != "null" ]] || continue
        F=$(ls "${TOP}/${CHANGELOG_ROOT}/${SLUG}"/pr-summary-*.md 2>/dev/null | sort | tail -1)
        check_artifact "${CHANGELOG_ROOT}/${SLUG}/pr-summary-*.md" "$F"
        ;;
      continuity)
        [[ -n "$CONTINUITY_ROOT" && "$CONTINUITY_ROOT" != "null" ]] || continue
        F=$(ls "${TOP}/${CONTINUITY_ROOT}"/*-"${SLUG}".md 2>/dev/null | sort | tail -1)
        check_artifact "${CONTINUITY_ROOT}/<date>-${SLUG}.md" "$F"
        ;;
      commitmsg)
        [[ -n "$CHANGELOG_ROOT" && "$CHANGELOG_ROOT" != "null" ]] || continue
        F="${TOP}/${CHANGELOG_ROOT}/${SLUG}/COMMITMSG.md"
        [[ -f "$F" ]] || F=""
        check_artifact "${CHANGELOG_ROOT}/${SLUG}/COMMITMSG.md" "$F"
        ;;
    esac
  done
fi

if [[ -z "$PROBLEMS" ]]; then
  # The close landed. Disarm so ordinary turns are never checked again.
  rm -f "$SENTINEL"
  exit 0
fi

DISARM='"${CLAUDE_PLUGIN_ROOT}"/hooks/verify-close-landed.sh --disarm'

REASON="/pr:close is not finished: its artifacts have not reached the PR.${PROBLEMS}

Per /pr:close step 8, invoke /pr:cp to stage, commit and push everything, then
re-check. Artifacts written after the last push are exactly what gets lost here.
If you are deliberately abandoning this close, disarm the sentinel:
  ${DISARM}"

if [[ "$HAVE_JQ" == "1" ]]; then
  jq -nc --arg r "$REASON" '{decision:"block",reason:$r}'
else
  # No jq, so no path list and no loop guard — but the ESCAPE must survive. A
  # degraded path is graceful only if it degrades the diagnosis while keeping the
  # recovery: without --disarm here, an unsatisfiable state (a rejected push, a
  # lock file) blocks every turn with no printed way out.
  printf '%s' '{"decision":"block","reason":"/pr:close artifacts have not landed: working tree dirty, tip unpushed, or a required artifact missing. Run /pr:cp, then re-check. (jq is unavailable, so the specific paths cannot be listed.) To abandon this close deliberately, run the hook with --disarm."}'
  printf '\n'
fi
exit 0
