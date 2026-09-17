#!/usr/bin/env node
/**
 * Node backend for reading the roster. Emits the normalized TSV described in
 * council-lib.sh:council_roster_rows, byte-identical to what the jq backend
 * produces for the same input.
 *
 * WHY THERE ARE TWO BACKENDS
 *
 * Nothing installs anything when a Claude Code plugin is installed: the manifest
 * has no dependency-resolution step, and `requires`/`postInstall` are ignored at
 * load time. So every binary this plugin touches is one the user already has, or
 * one the plugin must do without.
 *
 * Requiring jq specifically would have put a hard dependency on the exact path
 * that the sh-over-Node choice existed to protect -- a Claude-only council, which
 * needs neither Node nor a key, would have been unable to read its own status.
 * Requiring EITHER jq or Node is strictly weaker than requiring one of them, and
 * Node is already required the moment an OpenRouter member is seated.
 *
 * The fallback is Node rather than a regex, because the roster is nested: two
 * providers each carrying a `models[]`, plus per-provider `enabled` flags. The
 * sibling pattern in the `pr` plugin scrapes two flat scalars out of a hook
 * payload with sed, and says so in its own comments; that technique does not
 * reach a join, and a seating table that is confidently wrong about what a
 * council costs is worse than one that refuses to print.
 */

import { readFileSync } from "node:fs";

const path = process.argv[2];
if (!path) {
  process.stderr.write("usage: roster-rows.mjs <roster.json>\n");
  process.exit(2);
}

let roster;
try {
  roster = JSON.parse(readFileSync(path, "utf8"));
} catch (err) {
  // Both failure modes -- unreadable and unparseable -- exit non-zero so the
  // caller refuses rather than reporting an empty roster, which would be
  // indistinguishable from a Claude-only council.
  process.stderr.write(`${err.code === undefined ? "invalid JSON" : err.code}\n`);
  process.exit(2);
}

if (roster === null || typeof roster !== "object" || Array.isArray(roster)) {
  process.stderr.write("roster is not a JSON object\n");
  process.exit(2);
}

const out = [];
const ext = roster.external ?? {};
const or = ext.openrouter ?? {};
const ol = ext.ollama ?? {};
const cx = ext.codex ?? {};

const bool = (v) => (v === true ? "true" : "false");

out.push(`meta\tmaxConcurrentExternal\t${roster.maxConcurrentExternal ?? 2}`);
out.push(`meta\topenrouter.enabled\t${bool(or.enabled)}`);
out.push(`meta\tollama.enabled\t${bool(ol.enabled)}`);
out.push(`meta\tollama.endpoint\t${ol.endpoint ?? ""}`);
out.push(`meta\tcodex.enabled\t${bool(cx.enabled)}`);

const rows = (list, kind, idField) => {
  for (const m of Array.isArray(list) ? list : []) {
    if (m === null || typeof m !== "object") continue;
    out.push(`member\t${kind}\t${m.stance ?? "-"}\t${m[idField] ?? "-"}`);
  }
};

rows(roster.members, "claude", "model");
rows(or.models, "openrouter", "id");
rows(ol.models, "ollama", "id");

process.stdout.write(out.length ? `${out.join("\n")}\n` : "");
