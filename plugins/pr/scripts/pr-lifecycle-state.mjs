#!/usr/bin/env node
/**
 * Compute where the current branch sits in the PR lifecycle, what it is missing,
 * and which command comes next.
 *
 * Usage:
 *   node pr-lifecycle-state.mjs            # JSON to stdout
 *   node pr-lifecycle-state.mjs --text     # one-screen human summary
 *   node pr-lifecycle-state.mjs --offline  # skip every `gh` call
 *
 * Design rules, both load-bearing:
 *
 * 1. Detect missing OUTCOMES, never missing invocations. Whether someone typed
 *    `/pr:pre-test` is unobservable; whether CI has ever run on this branch is a
 *    fact. Outcomes are also what the operator actually cares about, and a PR the
 *    operator opened by hand satisfies the outcome just as well as one a skill opened.
 *
 * 2. A field we could not determine is `null`, and a `null` field NEVER produces a
 *    gap. Reporting a gap from an unreadable field is the absence-as-proof trap in
 *    reference/evidence-discipline.md, and a gate that false-positives trains the
 *    operator to ignore it.
 *
 * Every repo-shaped value comes from .claude/pr-config.json. See reference/config.md.
 */

import { execFileSync } from "node:child_process";
import { readdirSync, readFileSync } from "node:fs";
import { join, dirname, isAbsolute, resolve } from "node:path";

const argv = new Set(process.argv.slice(2));
const OFFLINE = argv.has("--offline");
const AS_TEXT = argv.has("--text");

/** Run a command, returning trimmed stdout, or null if it fails for any reason. */
function run(cmd, args, { cwd } = {}) {
  try {
    return execFileSync(cmd, args, {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    return null;
  }
}

/** Parse JSON, returning null rather than throwing, so a shape change degrades quietly. */
function parseJson(raw) {
  if (raw == null || raw === "") return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

// ------------------------------------------------------------------ repo roots
//
// The worktree we are in, and the main checkout that owns the config. They differ
// inside a linked worktree, which is exactly when one config must serve both.

const worktreeRoot = run("git", ["rev-parse", "--show-toplevel"]) ?? process.cwd();

function mainCheckout() {
  const common = run("git", ["rev-parse", "--git-common-dir"], { cwd: worktreeRoot });
  if (common == null) return worktreeRoot;
  const abs = isAbsolute(common) ? common : resolve(worktreeRoot, common);
  return dirname(abs);
}

const repoRoot = mainCheckout();

const git = (...args) => run("git", args, { cwd: worktreeRoot });

// ---------------------------------------------------------------------- config

const DEFAULTS = {
  repo: null,
  ticketPrefix: "",
  branchPrefix: "feature/",
  worktrees: { enabled: true, root: "../{repo}-Worktrees" },
  checks: { lint: null, typecheck: null, test: null, build: null },
  docs: { changelogRoot: "changelog", continuityRoot: "continuity", assertionsFile: "ASSERTIONS.md" },
  closeGate: { enabled: true, requiredArtifacts: ["pr-summary", "continuity"] },
  mainGuard: { enabled: true, approvalToken: "PR_ALLOW_MAIN" },
};

const CONFIG_PATH = join(repoRoot, ".claude", "pr-config.json");

function readConfig() {
  let raw = null;
  try {
    raw = readFileSync(CONFIG_PATH, "utf8");
  } catch {
    return { cfg: DEFAULTS, present: false };
  }
  const parsed = parseJson(raw);
  if (parsed == null) return { cfg: DEFAULTS, present: false, malformed: true };
  return {
    cfg: {
      ...DEFAULTS,
      ...parsed,
      worktrees: { ...DEFAULTS.worktrees, ...(parsed.worktrees ?? {}) },
      checks: { ...DEFAULTS.checks, ...(parsed.checks ?? {}) },
      docs: { ...DEFAULTS.docs, ...(parsed.docs ?? {}) },
      closeGate: { ...DEFAULTS.closeGate, ...(parsed.closeGate ?? {}) },
      mainGuard: { ...DEFAULTS.mainGuard, ...(parsed.mainGuard ?? {}) },
    },
    present: true,
  };
}

const { cfg, present: configPresent, malformed: configMalformed } = readConfig();

/** owner/name for `gh --repo`, from config or the origin remote. */
function resolveRepo() {
  if (cfg.repo) return cfg.repo;
  const url = run("git", ["remote", "get-url", "origin"], { cwd: worktreeRoot });
  if (url == null) return null;
  const m = url
    .replace(/^git@[^:]+:/, "")
    .replace(/^https?:\/\/[^/]+\//, "")
    .replace(/\.git$/, "");
  return /^[^/\s]+\/[^/\s]+$/.test(m) ? m : null;
}

const repo = resolveRepo();

// A gh call always names its repo. Without --repo, gh resolves from the cwd's
// remote, which is the same answer only until someone runs this from a worktree
// whose origin differs.
const gh = (...args) =>
  OFFLINE ? null : run("gh", repo ? [...args, "--repo", repo] : args, { cwd: worktreeRoot });

// -------------------------------------------------------------- default branch

function detectDefaultBranch() {
  const ref = run("git", ["symbolic-ref", "--quiet", "refs/remotes/origin/HEAD"], {
    cwd: worktreeRoot,
  });
  if (ref) return ref.replace(/^refs\/remotes\/origin\//, "");
  for (const cand of ["main", "master"]) {
    if (run("git", ["rev-parse", "--verify", "--quiet", `refs/remotes/origin/${cand}`], {
      cwd: worktreeRoot,
    })) {
      return cand;
    }
  }
  return "main";
}

const defaultBranch = detectDefaultBranch();
const originDefault = `origin/${defaultBranch}`;

// ---------------------------------------------------------------- branch + git

const branch = git("branch", "--show-current") || null;
const branchPrefix = cfg.branchPrefix ?? "";
const slug =
  branch && branchPrefix && branch.startsWith(branchPrefix)
    ? branch.slice(branchPrefix.length)
    : branch;
const detached = branch === null || branch === "";
const onDefault = branch === defaultBranch;

// --offline means no network at all, not merely no `gh`. Skipping the fetch leaves
// the ahead/behind counts measured against whatever was last fetched.
if (!OFFLINE) git("fetch", "origin", defaultBranch);

const countRevs = (range) => {
  const out = git("rev-list", "--count", range);
  return out == null ? null : Number.parseInt(out, 10);
};

const hasUpstream = git("rev-parse", "--abbrev-ref", "@{u}") != null;
const porcelain = git("status", "--porcelain");
const porcelainTracked = git("status", "--porcelain", "--untracked-files=no");

const gitState = {
  defaultBranch,
  commitsAheadOfDefault: branch ? countRevs(`${originDefault}..${branch}`) : null,
  commitsBehindDefault: branch ? countRevs(`${branch}..${originDefault}`) : null,
  unpushed: hasUpstream ? countRevs("@{u}..HEAD") : null,
  hasUpstream,
  dirtyTracked: porcelainTracked == null ? null : porcelainTracked !== "",
  untrackedOnly:
    porcelain == null || porcelainTracked == null
      ? null
      : porcelain !== "" && porcelainTracked === "",
};

// ------------------------------------------------------------------- artifacts

function dirEntries(path) {
  try {
    return readdirSync(path);
  } catch {
    return null;
  }
}

const changelogRoot = cfg.docs.changelogRoot;
const continuityRoot = cfg.docs.continuityRoot;

// Artifacts live in the worktree being worked in, not the main checkout.
const changelogDir = slug && changelogRoot ? join(worktreeRoot, changelogRoot, slug) : null;
const changelogFiles = changelogDir ? dirEntries(changelogDir) : null;
const has = (pred) => (changelogFiles == null ? null : changelogFiles.some(pred));

const continuityFiles = continuityRoot ? dirEntries(join(worktreeRoot, continuityRoot)) : null;

const artifacts = {
  changelogDir: changelogFiles != null,
  plan: has((f) => f === "PLAN.md"),
  changelog: has((f) => f === "CHANGELOG.md"),
  prSummary: has((f) => /^pr-summary-.*\.md$/.test(f)),
  prReview: has((f) => /^pr-review-.*\.md$/.test(f)),
  commitmsg: has((f) => f === "COMMITMSG.md"),
  // A disabled continuity convention is `null`, which is "not applicable" and never
  // a gap, exactly like an undetermined value.
  continuity:
    continuityRoot == null || slug == null
      ? null
      : continuityFiles == null
        ? false
        : continuityFiles.some((f) => f.endsWith(`-${slug}.md`)),
};

// ---------------------------------------------------------------------- ticket

function escapeRe(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** ^(?:<ticketPrefix>-)?(\d+)- applied to the slug, both parts from config. */
const ticketRe = new RegExp(
  `^(?:${cfg.ticketPrefix ? escapeRe(cfg.ticketPrefix) + "-" : ""})(\\d+)-`,
  "i",
);

const ticketNumber = slug ? (slug.match(ticketRe)?.[1] ?? null) : null;
const ticketPatternText = `${branchPrefix}${cfg.ticketPrefix ? cfg.ticketPrefix + "-" : ""}<number>-<slug>`;

let ticket = null;
if (ticketNumber) {
  const parsed = parseJson(
    gh("issue", "view", ticketNumber, "--json", "number,title,state,labels"),
  );
  ticket = parsed
    ? {
        number: parsed.number,
        title: parsed.title,
        state: parsed.state,
        labels: (parsed.labels ?? []).map((l) => l.name),
        resolved: true,
      }
    : {
        number: Number.parseInt(ticketNumber, 10),
        title: null,
        state: null,
        labels: null,
        // `gh` returned nothing. A missing issue and an unreachable or unauthenticated
        // `gh` are indistinguishable from here, so this never becomes a gap.
        resolved: false,
      };
}

// -------------------------------------------------------------------------- PR

const DRAFT_PLACEHOLDER = "<!-- pr:pre-test:draft-placeholder -->";

let pr = null;
if (branch && !onDefault) {
  const list = parseJson(
    gh(
      "pr",
      "list",
      "--head",
      branch,
      "--state",
      "all",
      "--json",
      "number,state,isDraft,body,closingIssuesReferences",
    ),
  );
  const found = Array.isArray(list) && list.length > 0 ? list[0] : null;
  if (found) {
    const body = found.body ?? "";
    pr = {
      number: found.number,
      state: found.state,
      isDraft: found.isDraft,
      bodyLength: body.length,
      // Anchored to the START of the body, never a substring search. /pr:pre-test
      // writes the marker as the body's first line, so a stub always starts with it,
      // while a real description that merely documents the marker in a code fence does
      // not. A plain `.includes()` here is the same defect as asserting a closing link
      // by string match: it fires on any PR whose description quotes the marker, which
      // every PR about this plugin does.
      bodyIsPlaceholder: body.trimStart().startsWith(DRAFT_PLACEHOLDER),
      // GitHub's OWN resolution of the closing keywords, never a string match on the
      // body. A `Closes #N` inside a code fence, inside a quote, or inside a sentence
      // that negates it satisfies a string match, and GitHub acts on none of them.
      closesIssues: (found.closingIssuesReferences ?? []).map((r) => r.number),
      hasCloses: ticketNumber
        ? (found.closingIssuesReferences ?? []).some(
            (r) => r.number === Number.parseInt(ticketNumber, 10),
          )
        : null,
      ci: null,
    };
    const checks = parseJson(gh("pr", "checks", String(found.number), "--json", "name,bucket"));
    if (Array.isArray(checks)) {
      // `cancel` and `skipping` must NOT fall through to "pass". A cancelled run
      // produced no verdict, and a workflow with cancel-in-progress leaves one behind
      // on every superseded push; calling that green would send the operator into a
      // close on a branch CI never validated. That is a false GREEN, the mirror of the
      // false positives this script is otherwise built to avoid, and the more dangerous
      // direction of the two.
      const buckets = checks.map((c) => c.bucket);
      pr.ci =
        buckets.length === 0
          ? "none"
          : buckets.includes("fail")
            ? "fail"
            : buckets.includes("pending")
              ? "pending"
              : buckets.includes("cancel")
                ? "cancelled"
                : buckets.every((b) => b === "skipping")
                  ? "skipped"
                  : "pass";
    }
  } else if (!OFFLINE && repo != null) {
    pr = { number: null, state: null, isDraft: null, bodyLength: null, ci: "none" };
  }
}

// --------------------------------------------------------------- phase + gaps

const gaps = [];
const addGap = (id, detail, remedy) => gaps.push({ id, detail, remedy });

const ahead = gitState.commitsAheadOfDefault;
const hasCommits = ahead != null && ahead > 0;

let phase;
if (detached) phase = "detached";
else if (onDefault) phase = "default-branch";
else if (pr?.state === "MERGED") phase = "merged";
else if (artifacts.commitmsg === true) phase = "closing";
else if (hasCommits) phase = "in-development";
else phase = "fresh";

// --------------------------------------------------------------------- steps
//
// One row per lifecycle step, keyed on the step's OUTCOME rather than on anyone
// having typed the command. `done` is tri-state: true, false, or null when the
// inputs needed to decide were not available.

const changelogPath = slug && changelogRoot ? `${changelogRoot}/${slug}` : null;

function pushedEvidence() {
  if (ahead == null) return null;
  if (gitState.unpushed == null) return `${ahead} commit(s) ahead of ${defaultBranch}`;
  return `${ahead - gitState.unpushed} of ${ahead} commit(s) pushed`;
}

// "CI has run" means it produced a verdict or is producing one. A cancelled or
// wholly-skipped run is not a verdict, so it leaves the branch still owing a CI pass.
const ciRan = pr?.ci === "pass" || pr?.ci === "fail" || pr?.ci === "pending";

/** Which artifacts the close gate requires, per config. */
const REQUIRED = new Set(cfg.closeGate.requiredArtifacts ?? []);
const requiredArtifactState = () => {
  const rows = [];
  if (REQUIRED.has("pr-summary")) rows.push(["pr-summary", artifacts.prSummary]);
  // A disabled continuity convention cannot be required; `null` drops out here rather
  // than blocking a close that was configured never to write one.
  if (REQUIRED.has("continuity") && artifacts.continuity !== null)
    rows.push(["continuity", artifacts.continuity]);
  if (REQUIRED.has("commitmsg")) rows.push(["commitmsg", artifacts.commitmsg]);
  return rows;
};

const closeDone = (() => {
  if (artifacts.commitmsg == null) return null;
  if (artifacts.commitmsg !== true) return false;
  if (requiredArtifactState().some(([, v]) => v !== true)) return false;
  return pr?.hasCloses === true;
})();

const steps =
  onDefault || detached
    ? []
    : [
        {
          step: "/pr:ticket",
          outcome: "a ticket exists for this branch",
          done: ticketNumber == null ? false : ticket?.resolved === true ? true : null,
          evidence:
            ticketNumber == null
              ? `branch name does not match ${ticketPatternText}`
              : ticket?.resolved
                ? `issue #${ticket.number} ${ticket.state}`
                : OFFLINE
                  ? `issue #${ticketNumber} not checked (offline)`
                  : `issue #${ticketNumber} could not be read`,
        },
        {
          step: "/pr:start",
          outcome: "the branch has a plan",
          done: artifacts.plan,
          evidence: artifacts.plan
            ? `${changelogPath}/PLAN.md`
            : `${changelogPath ?? "changelog folder"}/PLAN.md missing`,
        },
        {
          step: "/pr:cp",
          outcome: "the work is pushed",
          done: gitState.unpushed == null ? null : hasCommits && gitState.unpushed === 0,
          evidence: pushedEvidence(),
        },
        {
          step: "/pr:pre-test",
          outcome: "CI has run on this branch",
          done: pr == null ? null : ciRan,
          evidence: OFFLINE
            ? "PR and CI not checked (offline)"
            : pr?.number == null
              ? "no PR, so CI cannot have run"
              : `PR #${pr.number}, ci ${pr.ci ?? "unknown"}`,
        },
        {
          step: "/pr:summary",
          outcome: "a PR summary is written",
          done: artifacts.prSummary,
          evidence: artifacts.prSummary ? `${changelogPath}/pr-summary-*.md` : "no pr-summary yet",
        },
        {
          step: "/pr:close",
          outcome: "the close artifacts exist and the PR links the issue",
          done: closeDone,
          evidence:
            artifacts.commitmsg === true
              ? [
                  "COMMITMSG.md",
                  ...requiredArtifactState().map(([k, v]) => `${k} ${v ? "yes" : "no"}`),
                  `closing ref #${ticketNumber ?? "?"} ${pr?.hasCloses ? "present" : "absent"}`,
                ].join(", ")
              : "no COMMITMSG.md",
        },
        {
          step: "/pr:cleanup",
          outcome: "the merged branch is torn down",
          done: false,
          evidence:
            phase === "merged"
              ? "PR merged, worktree still present"
              : "not reached (branch is not merged)",
        },
      ];

// Each check below fires only on a value we actually determined.

if (configMalformed) {
  addGap("no-config", `${CONFIG_PATH} exists but is not valid JSON, so defaults are in use.`, "/pr:init");
} else if (!configPresent) {
  addGap("no-config", "No .claude/pr-config.json, so every value is a default.", "/pr:init");
}

if (branch && !onDefault && !detached) {
  if (ticketNumber == null) {
    addGap(
      "no-ticket",
      `Branch "${branch}" does not match ${ticketPatternText}, so no ticket can be resolved from it.`,
      "/pr:ticket",
    );
  }
  // An unresolved ticket (ticket.resolved === false) is deliberately NOT a gap: a
  // missing issue and an unreachable `gh` produce the identical result here, and
  // guessing between them is how a gate starts crying wolf.

  if (changelogRoot != null) {
    if (artifacts.changelogDir === false) {
      addGap(
        "no-plan",
        `${changelogPath}/ does not exist, so this branch was not opened with /pr:start.`,
        "/pr:start",
      );
    } else if (artifacts.plan === false) {
      addGap("no-plan", `${changelogPath}/PLAN.md is missing.`, "/pr:start");
    }
  }

  if (hasCommits && ticket?.labels?.includes("status:todo")) {
    addGap(
      "ticket-not-in-progress",
      `Issue #${ticketNumber} is still labelled status:todo while its branch has ${ahead} commit(s).`,
      "gh issue edit --remove-label status:todo --add-label status:in-progress",
    );
  }

  if (hasCommits && pr && pr.number == null) {
    addGap("no-ci", "No PR exists for this branch, so nothing has been checked.", "/pr:pre-test");
  } else if (pr?.ci === "none" && pr?.number != null) {
    addGap("no-ci", `PR #${pr.number} exists but no check run has reported.`, "/pr:pre-test");
  } else if (pr?.ci === "fail") {
    addGap("ci-failing", `CI is red on PR #${pr.number}.`, "fix the failing check");
  } else if (pr?.ci === "cancelled" || pr?.ci === "skipped") {
    addGap(
      "ci-no-verdict",
      `CI on PR #${pr.number} was ${pr.ci}, so it never produced a verdict.`,
      "push again, or re-run the workflow",
    );
  }

  // Body checks apply to a PR that is READY, never to a draft. A draft carrying the
  // /pr:pre-test placeholder is the state that skill deliberately creates, and it
  // holds for the whole development band; flagging it would fire a gap on correct
  // behaviour every single run, which is the failure this script exists to avoid.
  // /pr:close is what turns a draft ready, and it replaces the body when it does.
  if (pr?.number != null && pr.state === "OPEN" && pr.isDraft === false) {
    if (pr.bodyLength === 0) {
      addGap("pr-body-empty", `PR #${pr.number} is ready to merge with an empty body.`, "/pr:close");
    } else if (pr.bodyIsPlaceholder) {
      addGap(
        "pr-body-placeholder",
        `PR #${pr.number} is ready to merge but still carries the /pr:pre-test draft placeholder.`,
        "/pr:close",
      );
    } else if (pr.hasCloses === false) {
      addGap(
        "pr-missing-closes",
        `PR #${pr.number} has no resolved closing reference to #${ticketNumber}, so the merge will not close the issue.`,
        "/pr:close",
      );
    }
  }

  if (phase === "closing") {
    for (const [name, value] of requiredArtifactState()) {
      if (value === false) {
        addGap("close-incomplete", `COMMITMSG.md exists but no ${name} was written.`, "/pr:close");
      }
    }
  }

  if (gitState.unpushed != null && gitState.unpushed > 0) {
    addGap(
      "unpushed",
      `${gitState.unpushed} commit(s) are not pushed, so CI has not seen them.`,
      "/pr:cp",
    );
  }

  if (phase === "merged") {
    addGap("not-cleaned-up", `PR #${pr.number} is merged but this worktree still exists.`, "/pr:cleanup");
  }
}

// ----------------------------------------------------------------------- next

/**
 * The single next command, or null with a note saying why no command applies.
 * Ordered most-blocking first, so the first match wins.
 */
function nextCommand() {
  const hasGap = (id) => gaps.some((g) => g.id === id);

  if (detached) return [null, "HEAD is detached; check out a branch first."];
  if (onDefault) return ["/pr:next", null];
  if (phase === "merged") return ["/pr:cleanup", null];
  if (hasGap("no-plan")) return ["/pr:start", null];
  if (phase === "fresh") return [null, "No commits yet. Do the work, then /pr:cp."];
  if (pr?.ci === "fail") return [null, "CI is red. Fix the failing check before anything else."];
  if (hasGap("unpushed")) return ["/pr:cp", null];

  // Close is finished when its artifacts all exist. What remains is the operator's
  // merge, and cleanup is only reachable after that, so naming /pr:cleanup here would
  // contradict the close's own after-merge instruction.
  if (phase === "closing") {
    if (closeDone === true) return [null, "Close is complete. Merge the PR, then run /pr:cleanup."];
    return ["/pr:close", null];
  }

  // CI having run is what /pr:pre-test exists to achieve, so once it has, the branch
  // is through the work band and the close is what remains.
  return ciRan ? ["/pr:close", null] : ["/pr:pre-test", null];
}

const [next, nextNote] = nextCommand();

const state = {
  branch,
  slug,
  phase,
  repo,
  config: { present: configPresent, path: CONFIG_PATH, malformed: configMalformed === true },
  ticket,
  git: gitState,
  pr,
  artifacts,
  steps,
  next,
  nextNote,
  gaps,
  offline: OFFLINE,
};

// --------------------------------------------------------------------- output

if (!AS_TEXT) {
  console.log(JSON.stringify(state, null, 2));
} else {
  const yn = (v) => (v === null ? "-" : v ? "yes" : "no");
  const lines = [
    `repo     ${repo ?? "(unresolved)"}`,
    `branch   ${branch ?? "(detached)"}`,
    `phase    ${phase}`,
    ticket
      ? `ticket   #${ticket.number} ${ticket.state ?? "?"} ${(ticket.labels ?? []).join(", ")}`
      : "ticket   (none resolvable from the branch name)",
    pr?.number != null
      ? `pr       #${pr.number} ${pr.state}${pr.isDraft ? " (draft)" : ""}, body ${pr.bodyLength} chars, ci ${pr.ci ?? "?"}`
      : pr == null
        ? `pr       not checked (${OFFLINE ? "offline" : "gh unreadable"})`
        : "pr       none",
    `commits  ${gitState.commitsAheadOfDefault ?? "?"} ahead, ${gitState.commitsBehindDefault ?? "?"} behind ${defaultBranch}, ${gitState.unpushed ?? "?"} unpushed`,
    `plan     PLAN.md ${yn(artifacts.plan)}, pr-summary ${yn(artifacts.prSummary)}, COMMITMSG ${yn(artifacts.commitmsg)}, continuity ${yn(artifacts.continuity)}`,
  ];
  if (steps.length > 0) {
    // Compact one-liner first, for callers with a tight line budget such as /pr:status.
    const mark = (d) => (d === true ? "done" : d === false ? "--" : "?");
    lines.push(`done     ${steps.map((s) => `${s.step.replace("/pr:", "")} ${mark(s.done)}`).join("  ")}`);
    lines.push("steps");
    for (const s of steps) {
      const box = s.done === true ? "[x]" : s.done === false ? "[ ]" : "[?]";
      lines.push(`  ${box} ${s.step.padEnd(14)} ${s.evidence ?? "(undetermined)"}`);
    }
  }
  if (gaps.length === 0) {
    lines.push("gaps     none");
  } else {
    lines.push("gaps");
    for (const g of gaps) lines.push(`  ${g.id}: ${g.detail}  -> ${g.remedy}`);
  }
  lines.push(`next     ${state.next ?? state.nextNote ?? "(nothing to run)"}`);
  console.log(lines.join("\n"));
}
