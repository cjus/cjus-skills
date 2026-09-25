# Ticketing

Tickets are **GitHub issues** on the repo `.claude/pr-config.json` names. There is no external tracker, and the issue number **is** the ticket number.

See `config.md` for how `repo`, `ticketPrefix` and `branchPrefix` resolve, and for the slug and PR-title rules every skill shares.

## The lifecycle

```
/pr:ticket  ──>  status:todo  ──>  /pr:start  ──>  status:in-progress  ──>  (merge)  ──>  closed
```

- **`/pr:ticket` files as `status:todo` and `priority:high`.** New work enters the queue `/pr:next` draws from.
- **`/pr:start` swaps `status:todo` for `status:in-progress`.** That is the transition out of the queue, and no other skill performs it.
- **There is no `status:done`.** `/pr:close` puts `Closes #N` in the PR body and the **merge** closes the issue. A closed issue is a done ticket.
- **Closing an issue never touches its labels**, so `/pr:cleanup` removes `status:in-progress` after it confirms the merge. That is cosmetic, since the queue filters on `--state open`, but it keeps the closed list from reading as work still in flight.
- **`status:todo` on a closed issue is left alone.** It is the resting state and nothing reads it once the issue is closed.

## Labels

| Kind | Values | Notes |
|---|---|---|
| Status | `status:todo`, `status:in-progress` | Exactly one at a time. |
| Priority | `priority:high`, `priority:medium`, `priority:low` | `/pr:ticket` always files `priority:high`. |
| Type | `bug`, `feature`, `refactor`, `docs`, `infra`, `research` | Optional, at most one, and never guessed. |

`/pr:init` creates all of these. A repo may add its own type labels; skills read the three status and priority names and ignore anything else.

**A `status:todo` issue with no priority label is a queue defect.** Surface it as unprioritized and do not rank it. A missing label means the issue was filed outside `/pr:ticket`, and guessing a priority launders that into a decision nobody made.

**An issue with no `status:` label at all is invisible to the queue**, because `/pr:next` and `/pr:reviews` filter on `--label status:todo`. Only `/pr:triage`, which sweeps without a label filter, will ever surface it.

## Why `/pr:ticket` always files at high

It is turning a freeform description into a ticket nobody has ranked yet, so the band it picks carries no information either way. Filing high keeps new work visible in the queue until somebody ranks it deliberately. Do not add a note in the body suggesting a different priority; if the operator asks for one explicitly, honor that.

**`/pr:triage` diverges here deliberately.** A consolidated issue takes the band its members' own ranking implies rather than filing high, because those members were already ranked. Where the combining bar required them to agree, that agreed band is the answer. Where their changes land in one file or one migration the bar lets them disagree, and the group takes the **highest** member's band, with `/pr:triage` naming each promoted member in its report. Filing every consolidation high would instead promote the group past every other issue in its band on no evidence at all.

## Resolving a cited number

**GitHub shares one number sequence between issues and pull requests.** So `#412` may be a PR, and gaps in the ticket sequence mean nothing. Before treating a cited number as load-bearing, resolve it and confirm the title matches the claimed purpose:

```bash
gh issue view 412 --repo "$REPO" --json number,title,state,labels,url
```

**Resolve by number, never by searching titles.** A search over title and body readily returns a *different* issue that merely mentions the one you want: a follow-up, a spin-off, a duplicate report. Linking the wrong number closes someone else's ticket on merge, and unlike a missing link that failure is invisible afterward.

## PR numbers are not ticket numbers

The same shared sequence means **a PR's number never matches its ticket's.** The PR and its issue are two objects, and each takes its own number from the one sequence. Ticket #32 merged as PR #41, and without the title prefix its squash commit landed as `Bind a fixture book in CI so makebook changes get a signal (#41)`, with 32 appearing nowhere in it.

Each surface shows one number or both:

| Surface | Number shown | Put there by |
|---|---|---|
| Branch name and plan folder | ticket | `/pr:start` |
| PR title | ticket, as the `[#32]` prefix | `/pr:pre-test` on create, `/pr:close` on every run |
| PR URL, and every `gh pr` argument | PR | GitHub |
| PR body's closing reference, `Closes #32` | ticket | `/pr:close` |
| Squash commit subject on the default branch | both, as `[#32] <title> (#41)` | GitHub, from the PR title plus the PR number it appends |
| Lifecycle state line | both, as `PR #41 → closes #32` | `pr-lifecycle-state.mjs` |

**The squash subject carries the ticket only when GitHub takes that subject from the PR title.** Under the repo setting `squash_merge_commit_title: COMMIT_OR_PR_TITLE`, a PR with a single commit lands with that commit's subject instead, and the prefix never reaches the default branch. `PR_TITLE` closes that hole. `/pr:init` checks the setting and offers the change.

**The squash body does not reliably carry either number.** Under `squash_merge_commit_message: COMMIT_MESSAGES` it is the branch's own commit messages, so the PR body's `Closes #32` does not land in it.

**In a report, write a PR number as `PR #41`, never as a bare `#41`.** A bare `#N` is read as the ticket. Where both appear together, name the relationship, as in `PR #41 → closes #32`, so the reader never has to work out which one is which.

## Reporting a ticket

- **Discussing or updating an existing ticket: show its full URL**, `https://github.com/<owner>/<name>/issues/<number>`, once per ticket per message. A bare `#23` is not clickable in a terminal, and opening the issue is almost always the reader's next action. This covers status reports, review findings, triage output, and the confirmation line after editing an issue.
- **Reporting a ticket you just created: give the branch name and nothing else.** That is the one thing the reader acts on, since `/pr:start` consumes it. The title, labels, assignee and URL are all one click away and were not asked for.
