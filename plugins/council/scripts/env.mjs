#!/usr/bin/env node
/**
 * Council's `.env` reader and key-resolution chain.
 *
 * WHY THIS FILE EXISTS
 *
 * The skill's previous home reached sideways into its host repo for a parser:
 * `await import(<repoRoot>/scripts/dotenv.mjs)`, where `repoRoot` was three
 * levels up from `.claude/skills/council/`. Under any plugin layout that path is
 * wrong, and the `process.cwd()` fallback lands in a project that has no such
 * file. The import was top-level with no `try`/`catch`, so the whole member died
 * with `ERR_MODULE_NOT_FOUND` and exit code 1 -- a code the caller has no meaning
 * for, leaving it unable to tell "this member has no key" (exit 3, report it in
 * the footer) from "this script is broken". Everything needed is in here now.
 *
 * WHAT THIS DELIBERATELY IS NOT
 *
 * Not a dotenv clone. The host repo's parser is a version-pinned port of the
 * grammar Next.js bakes into a build, because it has to predict what `next build`
 * would inline into a bundle. Council has no such obligation: it resolves ONE
 * opaque token. So there is no `${VAR}` interpolation, no multi-line values, and
 * no `KEY: value` form. Each omission is one more thing that cannot go subtly
 * wrong with a secret inside it.
 *
 * One divergence from dotenv is deliberate and worth stating, because it is a
 * behavior difference rather than an omission. dotenv ends an unquoted value at
 * the first unescaped `#`, so `K=ab#cd` parses as `ab`. Applied to a credential
 * that silently TRUNCATES it, and a truncated key fails as an HTTP 401 (exit 4,
 * "the provider rejected us") rather than as anything that points at the file.
 * Here a `#` only starts a comment when whitespace precedes it, so `K=ab#cd`
 * keeps its value and `K=abcd # note` still drops the note.
 *
 * THE PRECEDENCE CHAIN
 *
 *   1. $COUNCIL_OPENROUTER_API_KEY in the environment   (per-invocation)
 *   2. ./.env in the current project                     (per-project)
 *   3. $XDG_CONFIG_HOME/council/.env, else
 *      ~/.config/council/.env                            (per-user default)
 *
 * Most-specific wins, the shape `git config` uses. A value that is present but
 * empty or all-whitespace counts as ABSENT at every level and falls through: an
 * empty key would otherwise reach the provider and come back 401, reporting a
 * configuration mistake as a provider failure.
 *
 * Council reads only the COUNCIL_ name and never bare OPENROUTER_API_KEY. That
 * is a seam, not an isolation boundary: the two may hold the same secret today,
 * and reading only the COUNCIL_ name keeps splitting them later a one-value edit.
 * If the unprefixed name belongs to an application, it stays that way.
 *
 * NO FLAG PRINTS THE VALUE, and none should be added. The key is returned to
 * importing code and never crosses a process boundary -- not argv, not stdout,
 * not a shell command line. `--probe` reports presence and provenance only.
 */

import { readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

export const KEY_NAME = "COUNCIL_OPENROUTER_API_KEY";

/**
 * `KEY=value`, with optional indentation and an optional `export ` prefix.
 * Anything else -- a blank line, a `#` comment, a `KEY: value` -- simply is not a
 * line we read, which is the same outcome as it not being there.
 */
const LINE = /^[ \t]*(?:export[ \t]+)?([A-Za-z_][A-Za-z0-9_]*)[ \t]*=[ \t]*(.*)$/;

/** A value that is missing, empty, or all whitespace is absent, not a key. */
function present(v) {
  return typeof v === "string" && v.trim() !== "";
}

/**
 * Strip quotes or a trailing comment from the right-hand side of one line.
 *
 * A quoted value is taken verbatim between its matching quotes: no escape
 * processing, and a `#` inside it is literal. If you quoted it, you meant it.
 * An unquoted value is trimmed and loses a ` #...` tail (see the header note on
 * why the whitespace is required).
 */
function unquote(rest) {
  const q = rest[0];
  if ((q === '"' || q === "'") && rest.length >= 2) {
    const end = rest.lastIndexOf(q);
    if (end > 0) return rest.slice(1, end);
  }
  // An unquoted value that BEGINS with `#` is a comment, not a value. The
  // whitespace that would otherwise mark it was already consumed by the `[ \t]*`
  // after the `=`, so the rule below cannot see it -- and without this line
  // `K=  # note` resolves to the literal string "# note", which then ships as a
  // Bearer token and comes back 401. Quote it if a key really starts with `#`.
  if (rest[0] === "#") return "";
  const comment = rest.search(/[ \t]#/);
  return (comment === -1 ? rest : rest.slice(0, comment)).trimEnd();
}

/**
 * Parse `.env` text into a Map. Exported because it is the part worth testing
 * exhaustively on its own, without a filesystem in the way.
 *
 * A repeated name takes its LAST assignment, matching dotenv, and matching what
 * someone appending a corrected line to the bottom of a file intends.
 */
export function parseEnvFile(text) {
  const out = new Map();
  for (const raw of text.split(/\r?\n/)) {
    const m = LINE.exec(raw);
    if (m) out.set(m[1], unquote(m[2]));
  }
  return out;
}

function defaultWarn(message) {
  process.stderr.write(`${message}\n`);
}

/** Render a path with `$HOME` as `~`, so provenance can be shown without doxxing a layout. */
export function displayPath(path, home = homedir()) {
  return home && path.startsWith(home) ? `~${path.slice(home.length)}` : path;
}

/**
 * Read one `.env`. Returns null when the file is not there, which is the
 * ordinary case -- that level of the chain is simply not in use.
 *
 * Any OTHER error is a level that is configured and FAILING (root-owned, a
 * directory where a file belongs), which is not the same as absent and must not
 * look like it. Warn, then fall through, so one broken level cannot take the
 * whole chain down.
 */
export function readEnvFile(path, { warn = defaultWarn, home = homedir() } = {}) {
  try {
    return parseEnvFile(readFileSync(path, "utf8"));
  } catch (err) {
    if (err.code !== "ENOENT") {
      warn(`council: cannot read ${displayPath(path, home)} (${err.code}) -- skipping this level`);
    }
    return null;
  }
}

/** `$XDG_CONFIG_HOME/council`, else `~/.config/council`. Matches how the roster is already located. */
export function configDir({ env = process.env, home = homedir() } = {}) {
  const xdg = env.XDG_CONFIG_HOME;
  return present(xdg) ? join(xdg, "council") : join(home, ".config", "council");
}

export function userEnvPath(opts) {
  return join(configDir(opts), ".env");
}

export function rosterPath(opts) {
  return join(configDir(opts), "roster.json");
}

/**
 * The user-level file holds a credential and nothing else, so it should be 600.
 * Warn rather than refuse: a readable key still works, and failing the council
 * over a permission bit would be a worse trade than saying so out loud.
 */
function checkMode(path, warn, home) {
  let mode;
  try {
    mode = statSync(path).mode & 0o777;
  } catch {
    return; // A mode we cannot read is not worth failing over.
  }
  if (mode & 0o077) {
    warn(
      `council: ${displayPath(path, home)} is mode ${mode.toString(8)} -- readable beyond its owner. chmod 600 it.`,
    );
  }
}

/**
 * Walk the chain. Returns the key and where it came from:
 *
 *   { value, source: "env" | "project" | "user" | null, path, display }
 *
 * `source` is the machine token; `display` is what a human-facing line should
 * print after "from". Callers that only want provenance must read those two and
 * leave `value` alone.
 */
export function resolveCouncilKey(opts = {}) {
  const {
    env = process.env,
    cwd = process.cwd(),
    home = homedir(),
    warn = defaultWarn,
  } = opts;
  const absent = { value: null, source: null, path: null, display: null };

  if (present(env[KEY_NAME])) {
    return { value: env[KEY_NAME], source: "env", path: null, display: "the environment" };
  }

  const projectPath = join(cwd, ".env");
  const project = readEnvFile(projectPath, { warn, home });
  if (project && present(project.get(KEY_NAME))) {
    return {
      value: project.get(KEY_NAME),
      source: "project",
      path: projectPath,
      display: displayPath(projectPath, home),
    };
  }

  const userPath = userEnvPath({ env, home });
  const user = readEnvFile(userPath, { warn, home });
  if (user && present(user.get(KEY_NAME))) {
    checkMode(userPath, warn, home);
    return {
      value: user.get(KEY_NAME),
      source: "user",
      path: userPath,
      display: displayPath(userPath, home),
    };
  }

  return absent;
}

/**
 * CLI. Presence and provenance only -- never the value.
 *
 * Exit 0 when a key resolved, 3 when none did, mirroring `openrouter.mjs`'s
 * "3 = no key configured, do not seat this member" so a shell caller can branch
 * on the status rather than parse the text.
 */
function main(argv) {
  const json = argv.includes("--json");
  const r = resolveCouncilKey();
  if (json) {
    process.stdout.write(
      `${JSON.stringify({ present: r.value !== null, source: r.source, path: r.path, display: r.display })}\n`,
    );
  } else if (r.value !== null) {
    process.stdout.write(`${KEY_NAME} present (from ${r.display})\n`);
  } else {
    process.stdout.write(`${KEY_NAME} absent\n`);
  }
  return r.value === null ? 3 : 0;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  process.exit(main(process.argv.slice(2)));
}
