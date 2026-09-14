# The assertion audit

Applies when `docs.assertionsFile` is configured. When it is `null`, every skill reports `assertions: disabled` once and skips this entirely.

No change is complete until it has been audited against the documented invariants of the area it touches.

## Discovery is a match, not a search

The assertions file is at the repo root, at the path config names. Do not scan directories or walk upward looking for it.

1. Take the change set: `git diff --name-only`, or the files you are about to edit.
2. Match those paths against the `Evidence` paths of each entry, and against every `Re-validate` trigger.
3. A hit puts that entry in scope. **No hit means no assertion is in scope and the audit is finished.** That outcome is normal and is not a reason to keep looking.

A turn with no change set at all has nothing to match and skips this section.

## Auditing an entry in scope

- **Cross-reference.** Flag every assertion whose evidence path, dependency, or trigger intersects the change set.
- **Verify.** Decide whether the change still satisfies the constraint, and cite the evidence: file plus symbol, test name, command output, query result. Static reading is not verification.
- **Decide.** Each impacted assertion ends in one of three states: **still satisfied** (cite why), **requires re-validation** (state how), or **violated**.

**A violation stops the work.** Surface it, propose either a code fix or an explicit assertion update with rationale, and wait for direction.

## Anchoring evidence

Follow the symbol-anchoring rules in `evidence-discipline.md`. Two additions specific to database objects:

**A migration filename is never a durable anchor for a function, view, policy or trigger.** Migrations are append-only and immutable once applied, so redefining one of those objects writes a **new** file and leaves the anchored one untouched. The filename is correct when written and silently wrong afterward, with nothing to flag the drift. Cite the symbol alone and resolve the current file on demand:

```bash
git log --oneline --reverse -S'<symbol>' -- <migrations-dir>/
```

**The boundary is how the object changes, not what kind of thing it is.** Functions, views, policies and triggers are *replaced*, so anchor the symbol only. Tables, columns and indexes are *altered in place*, so their creating migration stays true and may still be cited, amended inline for later columns.

**Do not add a CI gate that checks the definer filename.** It would convert silent staleness into forced churn: a heavily iterated function can see several redefinitions a day, and a filename gate costs a documentation edit on every one. The rule above is satisfiable once and then costs nothing per redefinition. That asymmetry is the design.

## Reporting, gated by artifact

**The full audit statement is required in reviewed artifacts:** implementation plans, PR summaries, `/pr:close`, and any edit to the assertions file. A reviewer reads those, so the enumeration is what proves the check ran.

```
## ASSERTION AUDIT

- Not impacted: A-001, A-002, A-003
- ⚠️ ASSERTION CHECK: A-004 is impacted by this change.
  - Detailed impact analysis: <why it remains valid, or how it requires re-validation, with cited evidence>
```

**Everywhere else**, in ordinary task-completion messages:

- Report impacted, needs-re-validation and violated entries only, with the same full analysis.
- Matched nothing? One line: `Assertions: none in scope.`
- A turn that writes no files omits the section entirely.

Rules that hold wherever the section appears:

- In the **full** statement every in-scope assertion appears by ID, collapsed or not, so a reviewer can confirm the audit ran. Dropping an unaffected ID there defeats the check.
- **Unaffected assertions collapse to one line.** One bullet per assertion is required only for entries that are impacted, need re-validation, or are violated.
- "Impacted but still valid" must cite verifiable evidence. Recognizing a pattern is not evidence.
- **The audit statement lives in the plan, the PR summary, or the task message. It is never appended into the assertions file**, which is atemporal and holds only current invariant entries. If an audit establishes or changes an invariant, edit that entry; do not also paste the audit narrative.
