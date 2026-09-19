#!/usr/bin/env node
/**
 * One OpenRouter council member, called from the `/council:ask` skill.
 *
 * Why this is a script and not an inline `curl` pipeline:
 *
 * 1. The key never enters argv, a shell command line, or stdout. It is read
 *    through `env.mjs:resolveCouncilKey` and used inside this process only.
 * 2. The prompt is read from a file, never interpolated into a command, so
 *    quotes, `$`, backticks and newlines need no escaping.
 * 3. It reads COUNCIL_OPENROUTER_API_KEY and deliberately NOT
 *    OPENROUTER_API_KEY. Council seats only its own key, which keeps council
 *    spend separable from whatever else on the machine uses OpenRouter. If the
 *    unprefixed name is set and belongs to an application, it stays that way.
 *
 * The key resolves most-specific-first -- the environment, then `./.env` in the
 * current project, then `$XDG_CONFIG_HOME/council/.env` (else `~/.config/council/.env`).
 * That chain lives in `env.mjs`
 * and is shared with `council-lib.sh`, so it is not implemented twice here.
 *
 * Usage:
 *   node "${CLAUDE_PLUGIN_ROOT}/scripts/openrouter.mjs" --model <id> --prompt-file <path>
 *
 * WHY FLAGS, AND NOT `M=` / `P=` IN THE ENVIRONMENT
 *
 * The earlier interface took both as environment variables, so every invocation
 * began `M=... P=... node ...`. Claude Code strips a leading assignment before
 * matching a permission rule only for a known-safe set of variable names, and `M`
 * and `P` are not in it -- so `Bash(node:*)` never matched and EVERY OpenRouter
 * member prompted the user. A narrower rule could not rescue it either:
 * `${CLAUDE_PLUGIN_ROOT}` does not expand inside a permission pattern, so the
 * script cannot be named there.
 *
 * Moving the model and the prompt PATH into argv costs nothing in secrecy. Only the
 * key has to stay out of the process table, and it still does -- point 1 above is
 * unchanged. A model id and a file path are not secrets.
 *
 * Exit codes, in the order they are checked:
 *
 *   5  bad usage -- a missing or unknown flag, OR a prompt file that cannot be
 *      read. Every usage problem is reported before the key chain is consulted, so
 *      a caller who mistyped something is never told their key is missing.
 *   3  no key configured. The caller must NOT seat this member, and must say so in
 *      the council footer.
 *   4  the provider answered, but not usefully: an HTTP error, or a 200 carrying no
 *      usable content. Exiting 0 with empty output would read as a member that
 *      answered with silence, and silence is not a position.
 */

import { readFile } from "node:fs/promises";
import { KEY_NAME, resolveCouncilKey, userEnvPath, displayPath } from "./env.mjs";

const ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";
const TIMEOUT_MS = 600_000;

const USAGE =
  "usage: node openrouter.mjs --model <id> --prompt-file <path>";

function badUsage(detail) {
  console.error(`${detail}\n${USAGE}`);
  process.exit(5);
}

let model = "";
let promptPath = "";

const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i += 1) {
  const arg = argv[i];
  let name = arg;
  let value;

  // Accept both `--flag value` and `--flag=value`; callers write either, and
  // rejecting one of them would be a trap rather than a contract.
  const eq = arg.indexOf("=");
  if (arg.startsWith("--") && eq !== -1) {
    name = arg.slice(0, eq);
    value = arg.slice(eq + 1);
  }

  if (name !== "--model" && name !== "--prompt-file") {
    badUsage(`unknown argument ${JSON.stringify(arg)}.`);
  }

  if (value === undefined) {
    value = argv[i + 1];
    i += 1;
  }
  // A value that is itself a flag means the previous one was left empty. Taking it
  // literally would send `--prompt-file` to OpenRouter as a model id.
  if (value === undefined || value === "" || value.startsWith("--")) {
    badUsage(`${name} needs a value.`);
  }

  if (name === "--model") model = value;
  else promptPath = value;
}

if (!model || !promptPath) {
  // A caller still on the retired interface gets told what changed, rather than a
  // bare usage line that reads as though they mistyped something.
  if (process.env.M || process.env.P) {
    badUsage("the M=/P= environment interface was replaced by --model / --prompt-file.");
  }
  badUsage("--model and --prompt-file are both required.");
}

// Read the prompt BEFORE resolving the key, so every usage error is reported ahead
// of any key problem. Previously this read happened after, and a rejection from it
// was not caught at all: a mistyped path exited 1 with a stack trace, which is a
// code the caller does not know and cannot act on.
let prompt;
try {
  prompt = await readFile(promptPath, "utf8");
} catch (cause) {
  badUsage(
    `cannot read the prompt file ${JSON.stringify(promptPath)}: ${cause.code ?? cause.message}`,
  );
}

const { value: key } = resolveCouncilKey();

if (!key) {
  // Name every level that was checked. "Not set" without the chain sends the
  // caller looking in one place, which is how a key lands in the file the tool
  // does not read.
  console.error(
    `${KEY_NAME} did not resolve. Checked, in order: the environment, ` +
      `${displayPath(`${process.cwd()}/.env`)}, and ${displayPath(userEnvPath())}. ` +
      "Do not seat this member; report it in the council footer. " +
      "Set the COUNCIL_ name rather than reading OPENROUTER_API_KEY here, so " +
      "council spend stays separable from any application using that key.",
  );
  process.exit(3);
}


// `model` is always sent: OpenRouter treats it as optional and silently falls
// back to the account default, which would misreport which member answered.
const response = await fetch(ENDPOINT, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({ model, messages: [{ role: "user", content: prompt }] }),
  signal: AbortSignal.timeout(TIMEOUT_MS),
});

if (!response.ok) {
  const body = await response.text().catch(() => "");
  console.error(`HTTP ${response.status} from OpenRouter: ${body.slice(0, 500)}`);
  process.exit(4);
}

const payload = await response.json();
const content = payload?.choices?.[0]?.message?.content;

if (typeof content !== "string" || content.trim() === "") {
  console.error("OpenRouter returned no message content; treat this member as absent.");
  process.exit(4);
}

process.stdout.write(content);
