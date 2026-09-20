#!/bin/bash
# Hook: PreToolUse (matcher "Bash"). Require operator approval for commit/push on
# the repo's default branch.
#
# reference/git-conventions.md: commit and push run without asking on feature
# branches; on the default branch they still need the operator. This hook IS that
# condition. A documented sentence is a behavioral expectation a long session or a
# compaction can lose; a PreToolUse decision is not.
#
# Why two verdicts instead of just "ask", established by probe:
#   - `permissionDecision: "ask"` overrides a Bash(git commit:*) / Bash(git push:*)
#     allow rule in settings.json, but ONLY in a mode that still prompts. Under
#     `permission_mode: "bypassPermissions"` it is silently a no-op: the command
#     ran with no prompt while the hook was confirmed firing and emitting "ask".
#   - `permissionDecision: "deny"` IS honored under bypassPermissions.
# So prompting modes get "ask" (one keypress); non-prompting modes get "deny",
# which forces a stop and a question instead of a silent commit.
#
# Escape hatch: a command carrying `<TOKEN>=1` passes, where <TOKEN> defaults to
# PR_ALLOW_MAIN and can be renamed via mainGuard.approvalToken. That is a SPEED
# BUMP, NOT A SECURITY BOUNDARY: under bypassPermissions the agent could set it
# itself. Its job is to make approval explicit and auditable in the transcript,
# and the workflow's rule is that it may only be added AFTER the operator approves
# in conversation.
#
# Decision table:
#   command is not a git commit/push     -> exit 0, no output
#   command carries the approval token   -> exit 0, no output
#   branch is not the default branch     -> exit 0, no output
#   branch IS the default branch         -> ask (prompting mode) / deny (otherwise)
#   ...but a ref-deleting push there     -> positional gate only is skipped; the
#                                           refspec checks below still apply
#   push whose refspec names it          -> same, whatever branch is checked out
#   branch undeterminable / no jq        -> same (fail toward the operator)
#   payload unparseable / not an object  -> deny (nothing in it is trustworthy,
#                                           the mode least of all)
#
# ON EVIDENCE: nearly every defence below exists because the obvious spelling was
# measured to fail open. Reading this file is not evidence that it works; two of
# the bypasses it now closes read as correct. This plugin ships NO test suite for
# it, which is a known gap: the behaviours were established by probe and by
# mutation testing during development, not by a suite you can re-run here.

INPUT=$(cat)

# A `git` invocation whose subcommand is commit or push, tolerating global options
# in between: `git commit`, `git -C /path push`, `git -c a=b commit`.
GIT_VERB='(^|[^[:alnum:]_./-])git[[:space:]]+(-[^[:space:]]+[[:space:]]+([^-[:space:]][^[:space:]]*[[:space:]]+)?)*(commit|push)([[:space:]]|;|&|\||$)'

# Default approval token. mainGuard.approvalToken can rename it, and that is read
# lazily below, only once we know this is a git command, so a non-git Bash call
# never pays for a config read.
ALLOW_NAME_DEFAULT="PR_ALLOW_MAIN"

# Cleared explicitly because it is READ before it is assigned, on the paths that run
# ahead of the payload parse. Without this an inherited environment variable named CWD
# would steer the activation check from outside the payload entirely. MODE is cleared
# for the same reason where it is defined below.
CWD=""

# `permission_mode` recovered from the raw payload, for the no-jq branch, which
# otherwise leaves MODE empty and so DENIES in every mode, including the ones that
# would merely prompt on the jq path.
#
# This may under-match freely and must NEVER over-match: failing to find the mode
# costs an operator round-trip, while wrongly finding a PROMPTING mode when the
# real one is bypassPermissions is silent, because `ask` is a no-op there and the
# commit lands.
#
# What blocks a forgery is that every `"` inside a JSON string value arrives as
# `\"`, so a command carrying `,"permission_mode":"default"` as text presents
# `permission_mode\"` and the pattern's `"` cannot match it.
#
# BE PRECISE ABOUT WHICH PART DEFENDS: it is the UNESCAPED CLOSING QUOTE, not the
# leading `[{,]`. Mutation-tested: dropping `[{,][[:space:]]*` changes nothing,
# because the closing quote already rejects every forgery, while tolerating an
# escaped quote (`\\?"`) opens it. The `[{,]` prefix is kept because it states
# "top-level key" for a reader and costs nothing, but it is NOT the safety
# property.
#
# Anything not matched leaves MODE empty, which gate() maps to `deny`. The
# mode-to-verdict mapping is NOT duplicated here on purpose: gate() stays the
# single place that decides.
MODE_RAW='[{,][[:space:]]*"permission_mode"[[:space:]]*:[[:space:]]*"([a-zA-Z]+)"'

MODE=""
HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

# grep's absence used to fail OPEN, which jq's never did. Every `grep -Eq` here is
# a pipeline, so a missing grep makes it exit 127, and the two tests that decide
# whether this is a git command at all are spelled `... || exit 0` and
# `if ...; then gate`, so a non-zero grep reads as "not a git command" and the
# hook exits silently.
#
# "Mirror how jq's absence is handled" does NOT work here, and the difference is
# worth stating because it is the obvious fix. jq's fallback still has grep to
# parse with; grep's fallback has nothing, so the same shape would have to gate
# EVERY Bash tool call, and this hook runs on all of them. That trades a silent
# failure for a wedged session.
#
# Bash's built-in `[[ =~ ]]` is the way out: an ERE engine that needs no process,
# so it can answer "is this a git command?" with grep gone. Verified to agree with
# `grep -E` on every GIT_VERB case, both multi-line forms, and every approval-token
# case including the ones that MUST NOT match, under bash 3.2.57, the oldest this
# will meet on macOS. It is used only to DETECT; anything past detection still
# needs grep, which is why the no-grep path gates rather than carrying on.
HAVE_GREP=0
command -v grep >/dev/null 2>&1 && HAVE_GREP=1

# True only when this repo opted INTO the workflow, which is what `.claude/pr-config.json`
# marks. The plugin declares its hooks in hooks/hooks.json, and a plugin enabled at user
# scope applies to EVERY repo the user opens: measured, not assumed, with a probe plugin
# that fired in a throwaway repo having no `.claude/` directory at all. Without this test
# a plugin install would gate default-branch commits in every repo on the machine.
#
# The asymmetry with the skills is deliberate: a skill is INVOKED and may sensibly run on
# defaults, while a hook is AMBIENT and may not.
#
# The config lives at the MAIN checkout's root, which is NOT $PWD inside a linked worktree,
# so it is resolved through `git rev-parse --git-common-dir` rather than a relative test.
# $CWD is the payload's cwd once parsed and unset before that, so the unparseable-payload
# gate falls back to $PWD and still asks the right repo.
#
# Needs NEITHER jq NOR grep, which is what lets it guard the degraded paths that exist
# precisely because one of those is missing.
pr_repo_configured() {
  # $PWD is NOT a trustworthy stand-in for the session's repo. CLAUDE_PROJECT_DIR is
  # exported for hook commands and IS the project dir, which `verify-close-landed.sh`
  # already relies on for the same reason; $PWD merely happens to be it sometimes, and
  # is kept only so a hand-run from a repo root still does something sensible.
  #
  # This matters most on the unparseable-payload path, which runs BEFORE $CWD is
  # assigned and whose whole contract is to deny. Resolving that path from $PWD alone
  # let a malformed payload pass silently whenever the hook's cwd sat outside the repo
  # -- fail-open on the one path built to fail closed, which is the defect class this
  # very ticket exists to remove.
  local dir="${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}" common
  common=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || return 1
  [[ -n "$common" ]] || return 1
  [[ "$common" == /* ]] || common="${dir}/${common}"
  [[ -f "$(dirname "$common")/.claude/pr-config.json" ]]
}

# Emit a decision. The reason is interpolated, so it is built with `jq --arg`
# rather than printf: a repo path containing a double quote otherwise produces
# unparseable stdout on the one branch designed to fail toward the operator, which
# loses the decision entirely. The printf fallback is reached only when jq is
# missing, and there the reason is a fixed literal with nothing to escape.
gate() {
  # Activation, checked HERE rather than at each call site so that EVERY gating path
  # honours it: the parsed path, the no-jq and no-grep paths that run before the config
  # read, the undeterminable-branch path, and any added later. gate() is the single
  # chokepoint through which every block must pass.
  pr_repo_configured || exit 0

  local reason="$1" decision
  case "$MODE" in
    default | acceptEdits | plan) decision="ask" ;;
    # Everything else, including `auto`, `dontAsk`, an empty mode, and any mode
    # added in future. Whether those actually prompt has NOT been established;
    # they are deliberately here because the two errors are not symmetric. A wrong
    # `deny` costs one operator round-trip; a wrong `ask` is a silent commit to the
    # default branch. Move a mode into the list above only with evidence.
    *) decision="deny" ;;
  esac

  [[ "$decision" == "deny" ]] &&
    reason="${reason} STOP and ask the operator in conversation. Only if they approve, re-run the command prefixed with ${ALLOW_NAME:-$ALLOW_NAME_DEFAULT}=1. Never add that yourself."

  if [[ "$HAVE_JQ" == 1 ]]; then
    jq -nc --arg d "$decision" --arg r "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  else
    # Reached only from the no-jq branch, which calls gate() with a fixed literal,
    # so nothing caller-controlled reaches this format string.
    #
    # The reason is printed IN FULL, escape hatch included, and that branch honours
    # the raw-token pattern so the instruction actually works there. Both halves
    # are load-bearing: a degraded path is graceful only if it degrades the
    # diagnosis while keeping the recovery, and printing a recovery that does
    # nothing is worse than printing none.
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$decision" "$reason"
  fi
  exit 0
}

if [[ "$HAVE_JQ" == 1 ]]; then
  # One jq spawn, not three, because this runs on EVERY Bash tool call, including the
  # overwhelming majority that are not git at all. The command is emitted last and
  # followed by a sentinel because it is the only field that can legitimately
  # contain newlines; @tsv would escape them and change what the regexes below
  # see, and taking the tail without a sentinel would misread an empty command.
  #
  # The `type != "object"` guard is part of the SAME expression, not a second
  # spawn: a payload that is valid JSON but not an object (`null`, `[]`, `42`)
  # otherwise yields empty fields and reads exactly like a Bash call that is not
  # git, i.e. it fails open.
  PAYLOAD=$(printf '%s' "$INPUT" |
    jq -r 'if type != "object" then error("payload is not an object") else . end
           | .cwd // "", .permission_mode // "", (.tool_input.command // ""), "--PR-GUARD-END--"' 2>/dev/null)
  JQ_RC=$?

  # Fail CLOSED when the payload did not parse. Before this check a malformed
  # payload was the one undeterminable state that passed silently: jq wrote
  # nothing, every field was empty, and the GIT_VERB test found no git in an empty
  # string, so the hook exited 0 with no output while the command ran.
  #
  # THE SENTINEL IS THE LOAD-BEARING HALF; `$JQ_RC` is belt-and-braces. Do not read
  # the order as importance, and do not delete the sentinel test as the
  # redundant-looking one. It is the opposite way round:
  #
  #   - jq's exit status does NOT catch EMPTY stdin. jq given no input runs the
  #     expression zero times and exits 0. Only the sentinel catches that.
  #   - The sentinel is the LAST thing the expression emits, so its presence proves
  #     the expression ran to completion. Every way jq can fail truncates before it.
  #
  # Mutation-tested: dropping the sentinel test reopens the empty-stdin hole;
  # dropping the `$JQ_RC` test changes no observable behaviour. The latter is kept
  # because it states the intent in the obvious way and costs nothing, but it is
  # not what closes the hole.
  #
  # This path DENIES rather than asks in every mode, and that is correct rather
  # than a repeat of the degraded path's always-deny defect. `permission_mode`
  # comes out of the same payload that just failed to parse, so there is nothing
  # here to trust, and guessing permissively is the unsafe direction.
  if [[ "$JQ_RC" != 0 || "$PAYLOAD" != *"--PR-GUARD-END--" ]]; then
    gate "The PreToolUse payload could not be parsed, so the default-branch commit guard cannot read the command."
  fi

  CWD=${PAYLOAD%%$'\n'*}
  PAYLOAD=${PAYLOAD#*$'\n'}
  MODE=${PAYLOAD%%$'\n'*}
  PAYLOAD=${PAYLOAD#*$'\n'}
  CMD=${PAYLOAD%$'\n'--PR-GUARD-END--}
else
  # Degraded: match against the raw payload. Over-matches, never under-matches.
  #
  # The approval token is honoured here too, otherwise this branch gates every git
  # command with no way past it while still printing "re-run prefixed with …" as
  # though that worked. Matched with bash's built-in regex rather than grep, so
  # this branch survives BOTH tools being absent.
  #
  # ONLY THE DEFAULT TOKEN NAME IS HONOURED HERE, because reading a renamed one
  # needs jq. A repo that renamed the token therefore still has the default name
  # working on this path. That is immaterial: the token is a speed bump rather than
  # a boundary (see the header), so the property that matters is that approval
  # stays explicit in the transcript, which it does under either name.
  #
  # The pattern is anchored to the `command` key, so it matches ONLY a command that
  # genuinely begins with the token. The obvious shortcut, reusing the unwrapped
  # pattern with `"` added to its delimiter class, is wrong in the dangerous
  # direction: in the raw payload a quoted argument's opening `"` is escaped as
  # `\"`, which that class matches, so `git commit -m "PR_ALLOW_MAIN=1 git x"`
  # forged approval here while the jq path correctly denied it. That is an
  # UNDER-match on the path whose whole contract is to over-match.
  #
  # The cost is that chain positions are not honoured without jq. That is the right
  # trade: the documented leading form still works, and everything else fails
  # toward the operator.
  ALLOW_TOKEN_RAW='"command"[[:space:]]*:[[:space:]]*"'"$ALLOW_NAME_DEFAULT"'=1[[:space:]]+([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git[[:space:]]'
  [[ $INPUT =~ $ALLOW_TOKEN_RAW ]] && exit 0

  # Recover the mode so this branch ASKS where the jq path would ask. Without this
  # it denied in every mode, which inverted the degraded path's contract in the
  # annoying direction. Deliberately NOT shared with the unparseable-payload gate
  # above: there the mode comes from a payload that just failed to parse and is not
  # trustworthy; here the payload is well-formed and only the parser is missing.
  if [[ $INPUT =~ $MODE_RAW ]]; then MODE="${BASH_REMATCH[1]}"; fi

  [[ $INPUT =~ $GIT_VERB ]] &&
    gate "jq not found, so the default-branch commit guard cannot read the command."
  exit 0
fi

# Same fallback chain as pr_repo_configured, and it has to be spelled out HERE too:
# this assignment runs BEFORE the activation check, so writing a bare "$PWD" would
# shadow CLAUDE_PROJECT_DIR inside that function and the chain there would never be
# reached. A payload that parses but carries an empty cwd then resolved activation
# from the process's working directory, which fails OPEN whenever that sits outside
# the repo. Measured. Matches verify-close-landed.sh:142.
[[ -n "$CWD" ]] || CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

# No grep: detect with bash's built-in regex and gate if this is a git command.
# Everything past this point needs grep to EXTRACT rather than merely match, so
# there is no honest way to carry on. A non-git command is still passed through
# untouched, which is what keeps the session usable.
#
# This runs AFTER the payload parse on purpose: MODE is known by now, so a
# prompting mode gets `ask` rather than the `deny` a pre-parse check would force.
if [[ "$HAVE_GREP" == 0 ]]; then
  [[ $CMD =~ $GIT_VERB ]] &&
    gate "grep not found, so the default-branch commit guard cannot parse the command."
  exit 0
fi

printf '%s' "$CMD" | grep -Eq "$GIT_VERB" || exit 0

# ---- From here on we know this is a git commit/push, so a config read is cheap.

ALLOW_NAME="$ALLOW_NAME_DEFAULT"
GUARD_ENABLED="true"

COMMON=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null)
if [[ -n "$COMMON" ]]; then
  [[ "$COMMON" == /* ]] || COMMON="${CWD}/${COMMON}"
  CONFIG="$(dirname "$COMMON")/.claude/pr-config.json"
  if [[ -f "$CONFIG" ]]; then
    v=$(jq -r '.mainGuard.approvalToken // empty' "$CONFIG" 2>/dev/null)
    [[ -n "$v" ]] && ALLOW_NAME="$v"
    v=$(jq -r 'if .mainGuard.enabled == false then "false" else "true" end' "$CONFIG" 2>/dev/null)
    [[ -n "$v" ]] && GUARD_ENABLED="$v"
  fi
fi

[[ "$GUARD_ENABLED" == "true" ]] || exit 0

# Operator already approved this specific invocation. The token must be a leading
# env assignment that actually INTRODUCES a git command, optionally after other
# assignments, and optionally at a chain position.
#
# Accepting a bare metacharacter before the token was a live bypass: a commit whose
# MESSAGE contained `; PR_ALLOW_MAIN=1 to override` disabled the guard by writing
# ordinary prose. A message that forges the whole `; <TOKEN>=1 git ` prefix still
# passes; that is the speed-bump boundary named in the header.
ALLOW_TOKEN='(^|[;&|(]|&&|\|\|)[[:space:]]*'"$ALLOW_NAME"'=1[[:space:]]+([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git[[:space:]]'
printf '%s' "$CMD" | grep -Eq "$ALLOW_TOKEN" && exit 0

# Strip one layer of shell quoting from an extracted path.
unquote() {
  local v="$1"
  v="${v%\"}" v="${v#\"}"
  v="${v%\'}" v="${v#\'}"
  printf '%s' "$v"
}

# Escape a branch name for safe interpolation into an ERE.
ere_escape() {
  printf '%s' "$1" | sed -E 's/[][\.*^$+?(){}|\/]/\\&/g'
}

# True when this invocation is a REF-DELETING push (`git push --delete <branch>` or
# its `-d` short form), which is the one push whose blast radius has nothing to do
# with the branch that happens to be checked out.
#
# Why this exists: the checked-out-branch gate reads "on the default branch, commit
# and push need approval", and for every OTHER push that is right, because the
# working branch is what a bare `git push` writes. A delete push writes no commits
# anywhere; it removes a named ref on the remote. Running one from the default
# branch is not merely safe, it is the NORMAL case -- a worktree cannot remove
# itself, so `/pr:cleanup` always deletes the merged branch from the main checkout
# and so always tripped this gate. A guard that fires on every correct run of a
# workflow the same plugin ships is training the operator to wave it through, which
# is the failure the `ask`-vs-`deny` split above exists to avoid.
#
# THIS NARROWS ONE GATE ONLY. The caller falls straight through to the refspec
# checks, so `git push origin --delete main` still gates on the default-branch ref
# class, `--mirror`/`--all` still gate, and a wildcard refspec still gates. What is
# dropped is the POSITIONAL check, not the check on what is being written.
#
# HEAD and `@` are excluded rather than left to the refspec class, and that
# exclusion is the reason this is a function and not a one-line test. `git push
# origin --delete HEAD` resolves HEAD locally, so run from the default branch it
# deletes the default branch on the remote -- while the literal text `HEAD` never
# matches the default-branch pattern below. Exempting it would open a bypass
# spelled more simply than the form it replaced. Anything whose target is not an
# explicitly named ref keeps the positional gate.
is_ref_delete_push() { # invocation slice, argument region
  case "$1" in *push*) ;; *) return 1 ;; esac
  printf '%s' "$2" | grep -Eq '(^|[[:space:]])(-d|--delete)([[:space:]]|$)' || return 1
  # A ref token, delimited the same way the default-branch pattern delimits one, so
  # `HEADER` and `user@host` are not mistaken for the symbolic forms.
  printf '%s' "$2" | grep -Eq "(^|[[:space:]:/+\"'])(HEAD|@)([^[:alnum:]._/-]|\$)" && return 1
  return 0
}

# Resolve the branch of the repo the invocation acts on. `$@` is the repo selector
# (`-C <dir>` or `--git-dir=<dir>`), passed through verbatim.
#
# `symbolic-ref` FIRST, and that ordering is the whole point of this function.
# `rev-parse --abbrev-ref HEAD` answers with the literal string `HEAD` in two
# states, printing it on stdout with a non-zero exit that `2>/dev/null` hides:
#
#   - A DETACHED HEAD, where the branch genuinely is undeterminable. `HEAD` is
#     non-empty and is not the default branch, so both checks below passed and the
#     command went ungated.
#   - An UNBORN branch (a repo with no commits), where the answer is knowable and
#     `rev-parse` gets it wrong. That is how the bug was found: a repo sat at zero
#     commits and its first commit, the one that creates the default branch, went
#     through ungated.
#
# `symbolic-ref --short HEAD` reads the ref HEAD points at, which is right for the
# unborn case (the ref exists before any commit does) and exits non-zero on a
# detached HEAD, which is what we want, since an empty BRANCH gates. Mapping a
# literal `HEAD` back to empty covers the fallback path.
resolve_branch() {
  local b
  b=$(git "$@" symbolic-ref --short HEAD 2>/dev/null)
  [[ -n "$b" ]] || b=$(git "$@" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [[ "$b" == "HEAD" ]] && b=""
  printf '%s' "$b"
}

# The repo's default branch, asked of the repo the invocation acts on. Falls back
# to `main` when the remote HEAD is not set, which is the common case in a fresh
# local repo and keeps the guard meaningful there.
resolve_default_branch() {
  local d
  d=$(git "$@" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  d="${d#origin/}"
  if [[ -z "$d" ]]; then
    for cand in main master; do
      if git "$@" rev-parse --verify --quiet "refs/heads/$cand" >/dev/null 2>&1; then
        d="$cand"
        break
      fi
    done
  fi
  printf '%s' "${d:-main}"
}

# EVERY git commit/push invocation in the command, in order, not just the first. A
# chain carries more than one, and judging only the first missed the one that
# mattered: `git commit -m x && git push origin main` from a feature branch went
# ungated, because the leading slice is the `commit` and the whole push block was
# then skipped. Each invocation is judged on ITS OWN options and argument list, so
# a later `-C` cannot be attributed to an earlier command.
#
# The remainder is RE-SCANNED each iteration rather than enumerated once up front.
# That is not a refactor: GIT_VERB's trailing group consumes the separator, so in
# `git commit;git push origin main` a single `grep -Eo` pass ends the first match
# past the `;`, and the second `git` then has no preceding character left to
# satisfy `(^|[^[:alnum:]_./-])`, hiding the push entirely.
#
# Scanning `$REST` rather than `$CMD` is also what makes the loop TERMINATE: the
# match always comes from the remainder, so `${REST#*"$INV"}` always shortens it.
# Point grep back at `$CMD` and the hook spins forever on the first chained command
# it sees.
#
# The loop runs in THIS shell (no pipe, no subshell), which is what lets gate()'s
# `exit` end the hook rather than just one iteration.
REST="$CMD"
while :; do
  INV=$(printf '%s' "$REST" | grep -Eo "$GIT_VERB" | head -1)
  [[ -n "$INV" ]] || break

  # This invocation's arguments: the text after it, cut at the next shell
  # separator so a later command's words are never read as this one's refspec.
  TAIL=${REST#*"$INV"}

  # The cut is QUOTE-AWARE. A blind cut also fired on a separator inside a quoted
  # argument, so `git push --push-option='a;b' origin main` lost its refspec and
  # passed. Only an unquoted `;`, `|`, `&` or NEWLINE ends the region.
  #
  # Quote state is initialised in BEGIN, NOT per line, and an unquoted newline ends
  # the region. Both halves are load-bearing and both were wrong once:
  #
  #   Per-line initialisation lost the quote state at every newline, so a quoted
  #   argument spanning lines went "unquoted" and a later `;` cut the region short,
  #   dropping the refspec behind it. A fail-OPEN bypass.
  #
  #   Not treating a newline as a separator was worse once the walk began advancing
  #   past SEG: awk printed EVERY line, so on any multi-line command SEG equalled
  #   TAIL, REST went empty, and the walk stopped after the FIRST invocation. A
  #   plain `git add -A` / `git commit` / `git push origin main` across three lines
  #   then reached the default branch ungated.
  #
  # A newline IS a shell command separator, so ending the region there is the same
  # rule the other separators already state. A newline INSIDE quotes is preserved,
  # because a multi-line commit message is one argument.
  SEG=$(printf '%s' "$TAIL" | awk '
    BEGIN { inS = 0; inD = 0; out = ""; done = 0 }
    {
      if (done) next
      if (NR > 1) {
        if (!inS && !inD) { done = 1; next }
        out = out "\n"
      }
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c == "\047" && !inD) inS = !inS
        else if (c == "\"" && !inS) inD = !inD
        if (!inS && !inD && (c == ";" || c == "|" || c == "&")) { done = 1; break }
        out = out c
      }
    }
    END { printf "%s", out }')

  # Advance PAST this invocation's own argument region, not merely past the verb.
  #
  # Scanning used to resume immediately after the verb, so the invocation's own
  # arguments were re-scanned as if they were a new command, and a quoted commit
  # MESSAGE is an argument. `git commit -m "docs: explain git push origin main"`
  # therefore produced a second invocation out of the message text, whose SEG
  # matched the refspec class and gated a perfectly ordinary commit.
  #
  # The `case` is load-bearing, not defensive. GIT_VERB's trailing group can
  # CONSUME the separator: in `git commit;git push origin main` the first match is
  # `git commit;`, so TAIL is already the next command and SEG is that whole
  # command. Advancing past SEG there would swallow the real push. When INV ends in
  # a separator the argument region is empty, so TAIL is the right resume point.
  #
  # The prefix test is belt-and-braces: SEG is built character by character from
  # TAIL, so it IS a literal prefix by construction. It is kept because the cost is
  # nothing and the failure it would absorb is a lost invocation.
  case "$INV" in
    *[\;\&\|]) REST="$TAIL" ;;
    *)
      if [[ "$TAIL" == "$SEG"* ]]; then REST=${TAIL#"$SEG"}; else REST="$TAIL"; fi
      ;;
  esac

  # `git -C <dir> …` and `git --git-dir=<dir> …` act on another repo, not on the
  # session's cwd, so ask THAT repo for the branch. Otherwise a feature-branch
  # worktree could commit to a default-branch checkout unguarded, which was
  # verified for --git-dir: it wrote a real commit to a fixture while this hook
  # passed it through.
  #
  # Read from the invocation slice only, never the whole command: a git option is
  # only an option where git can see it, and reading the whole string let a commit
  # MESSAGE naming `--git-dir=<other repo>` redirect the lookup. A path that does
  # not resolve yields an empty branch, which gates.
  #
  # The sticky `-C<dir>` form (no space) is deliberately NOT handled: git itself
  # rejects it, so such a command cannot commit anything.
  GITDIR=$(printf '%s' "$INV" |
    grep -Eo '(^|[[:space:]])--git-dir[=[:space:]][[:space:]]*[^[:space:]]+' | head -1 |
    sed -E 's/.*--git-dir[=[:space:]][[:space:]]*//')
  GITDIR=$(unquote "$GITDIR")

  TARGET=$(printf '%s' "$INV" | grep -Eo '(^|[[:space:]])-C[[:space:]]+[^[:space:]]+' | head -1 | awk '{print $2}')
  TARGET=$(unquote "$TARGET")

  if [[ -n "$GITDIR" ]]; then
    [[ "$GITDIR" == /* ]] || GITDIR="${CWD}/${GITDIR}"
    LOCATION="$GITDIR"
    BRANCH=$(resolve_branch --git-dir="$GITDIR")
    DEFAULT_BRANCH=$(resolve_default_branch --git-dir="$GITDIR")
  else
    TARGET_REPO="$CWD"
    if [[ -n "$TARGET" ]]; then
      [[ "$TARGET" == /* ]] && TARGET_REPO="$TARGET" || TARGET_REPO="${CWD}/${TARGET}"
    fi
    LOCATION="$TARGET_REPO"
    BRANCH=$(resolve_branch -C "$TARGET_REPO")
    DEFAULT_BRANCH=$(resolve_default_branch -C "$TARGET_REPO")
  fi

  if [[ -z "$BRANCH" ]]; then
    gate "Could not determine the branch in ${LOCATION}, so the default-branch guard cannot clear this commit/push."
  fi

  # The POSITIONAL gate: what the checked-out branch alone implies. A ref-deleting
  # push is the documented exception, because the checked-out branch says nothing
  # about which ref it removes; see is_ref_delete_push. It still faces every
  # refspec check below.
  if [[ "$BRANCH" == "$DEFAULT_BRANCH" ]] && ! is_ref_delete_push "$INV" "$SEG"; then
    gate "On ${DEFAULT_BRANCH}: commit and push need operator approval."
  fi

  [[ "$INV" == *push* ]] || continue

  DB_RE=$(ere_escape "$DEFAULT_BRANCH")

  # The default branch as a ref, however it is delimited. `+` is the leading force
  # marker, so without it the ONE form that rewrites history there was the one that
  # passed, which is what hid it: every sibling form already gated. Quotes join the
  # class because `git push origin 'main'` is the same push with the same
  # consequences.
  #
  # The two groups are deliberately NOT symmetric, and making them so breaks it.
  #
  #   Leading: an ENUMERATION of what may precede a ref: whitespace, `:`, `/`, the
  #   `+` force marker, a quote. `/` must stay a *delimiter* here so
  #   `refs/heads/main` matches; a "not a ref character" class would treat the `/`
  #   as part of the name and let that form through.
  #
  #   Trailing: a NEGATION: the name must not be followed by another ref-name
  #   character, i.e. it has to be a complete ref token. The old spelling
  #   enumerated `[[:space:]"']|$` instead, which silently made every OTHER
  #   trailing character a bypass: `(git push origin main)` and the backtick and
  #   `$(...)` forms all passed, differing from the bare command in nothing but the
  #   character after the name. A delimiter bug, not a subshell one.
  #
  # Ref names may contain alnum, `.`, `_`, `/` and `-`, so those are what must NOT
  # follow. That is what keeps `maintenance`, `mainline`, `main-2`, `main.x`,
  # `main/foo` and `domain` passing, which matters as much as the gating: a guard
  # that gates every branch is as useless as one that gates none.
  if printf '%s' "$SEG" | grep -Eq "(^|[[:space:]:/+\"'])${DB_RE}([^[:alnum:]._/-]|\$)"; then
    gate "Push targets ${DEFAULT_BRANCH}: needs operator approval."
  fi

  # Whole-repo pushes name no ref but write every branch, the default among them.
  # `--mirror` also implies --force, so it is the most destructive spelling here
  # and the one least likely to be typed deliberately.
  if printf '%s' "$SEG" | grep -Eq '(^|[[:space:]])--(mirror|all)([[:space:]]|=|$)'; then
    gate "Push writes every branch, ${DEFAULT_BRANCH} included: needs operator approval."
  fi

  # A wildcard refspec expands to include the default branch. Deliberately
  # conservative: a wildcard that could not match it still gates, because deciding
  # that requires expanding it against the remote.
  if printf '%s' "$SEG" | grep -Eq '\*'; then
    gate "Push uses a wildcard refspec, which can include ${DEFAULT_BRANCH}: needs operator approval."
  fi
done

exit 0
