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
 * Usage:  M=<model-id> P=<prompt-file> node "${CLAUDE_PLUGIN_ROOT}/scripts/openrouter.mjs"
 *
 * Exit codes: 3 = no key configured (caller must NOT seat this member and must
 * say so in the footer), 4 = HTTP error, 5 = bad usage.
 */

import { readFile } from "node:fs/promises";
import { KEY_NAME, resolveCouncilKey, userEnvPath, displayPath } from "./env.mjs";

const ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";
const TIMEOUT_MS = 600_000;

const model = process.env.M;
const promptPath = process.env.P;

if (!model || !promptPath) {
  console.error("usage: M=<model-id> P=<prompt-file> node openrouter.mjs");
  process.exit(5);
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

const prompt = await readFile(promptPath, "utf8");

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
