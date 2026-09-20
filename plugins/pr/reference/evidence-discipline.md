# Evidence discipline

Applies continuously while working, not only when a skill asks for it. Every skill in this plugin assumes it.

## Classify each factual claim before asserting it

- **Verified.** Backed by a tool result present in this conversation: a file excerpt, a grep hit, a git log line, command output. State it plainly and cite the source as `file:line`, a commit hash, or the command that produced it.
- **Inferred.** A reasonable extrapolation from verified evidence, not directly observed. Hedge with exactly **one** qualifier. A single hedge carries a confidence signal; stacking them destroys it.
- **Unsupported.** No source exists in this conversation. Verify it, retract it, or rewrite it with an explicit "I have not verified this".

**Reading code statically does not verify runtime behavior.** Recognizing a pattern is not the same as having tested it, and convention does not confirm a path.

## Fabrication patterns to watch for in your own output

- Line numbers you did not read
- Function, variable, or file names you did not grep for or open
- File paths assumed from convention rather than confirmed
- Metrics, percentages, or counts not computed from observed data
- "I tested / verified / confirmed" when no such tool call was made
- Historical claims ("this was added because…") without `git log` or `git blame`
- Confident assertions about runtime behavior on code paths only read statically
- **Speculative gap-filling.** Writing that a source could not be found, then inventing plausible detail to cover the gap. The reader cannot separate the invented half from the sourced half, which is why this costs more than an ordinary unsupported claim. State what is not known, or cut the sentence.

## Treating an absence as proof

"I looked and found nothing" bounds only the places you looked.

- A `git log --all` miss means "not committed **yet**", not "never".
- An `origin/main` miss means "not merged **yet**".
- A clean production ledger means "not applied **there**".

None of them rules out a sibling worktree, an unmerged branch, or a change applied by hand. **Before an absence becomes load-bearing, especially when it is your grounds for dismissing a warning, name the places you did not check and decide whether they matter.**

This is the most expensive mistake in the list. A review finding was once correctly raised and then rejected on exactly this reasoning, because two checks came back clean and a third place nobody looked was where the conflict lived.

## Ask the system, not the text

Where a platform will act on something, assert on the platform's own resolution of it rather than on a string that looks like it.

`Closes #N` is the case that proves the rule. A body containing that string inside a code fence, inside a blockquote, or inside a sentence that negates it satisfies `body.includes("Closes #123")`, and GitHub acts on none of those. The only honest check is GitHub's resolved closing references:

```bash
gh pr view "$PR" --repo "$REPO" --json closingIssuesReferences
```

A PR whose body documents the closing syntax in an example command, which any PR about this plugin will, passes the string check while the merge closes nothing.

**Where no platform resolution exists, anchor the match to a position rather than searching the whole text.** A generated stub always *starts with* its marker, so `trimStart().startsWith(marker)` separates the stub from a document that merely mentions the marker. The general failure is the same both times, so check for it whenever a rule keys on text a human also writes about.

## Anchoring evidence to symbols, not line numbers

Line numbers are fragile: one insert upstream silently invalidates every reference below it, and nothing flags the drift. Anchor durable references to stable identifiers instead.

| Kind | Anchor |
|---|---|
| Function, method, class | `path/to/file.ts → functionName()` |
| Exported constant or type | `path/to/file.ts → CONSTANT_NAME` |
| Component | `path/to/Component.tsx → <ComponentName>` |
| Config key | `path/to/file.json → key.path.dotted` |
| Distinctive string literal (last resort) | `path/to/file.ts → "exact unique substring"` |

Use line numbers only as a transient hint while actively editing, never as the durable record.

**Re-verify the cited property, not just the pointer.** A dead pointer is obvious; a pointer that still resolves while describing behavior that has since changed is not. When you touch an anchor, confirm the specific claim it makes against the current definition.

## Issuing a correction

When you discover a prior claim was unsupported or over-confident, post the retraction in this format rather than quietly dropping it:

```
Claim: "<exact wording>"
Status: unsupported | over-confident | verified after recheck
Correction: <retraction, hedge, or citation>
```

**A clean re-audit reports nothing.** If a re-audit finds nothing to correct, say so in a clause and move on. Do not manufacture a hedge to prove the check ran; a per-turn correction quota produces noise and trains the reader to skip the corrections that matter.
