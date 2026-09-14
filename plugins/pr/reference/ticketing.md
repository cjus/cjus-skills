# Ticketing

Tickets are **GitHub issues** on the repo `.claude/pr-config.json` names. There is no external tracker, and the issue number **is** the ticket number.

See `config.md` for how `repo`, `ticketPrefix` and `branchPrefix` resolve, and for the slug rule every skill shares.

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

**`/pr:triage` diverges here deliberately.** A consolidated issue inherits the shared band of its members, because those were already ranked and the combining bar required them to agree. Forcing high there would silently promote the group past every other issue in its band.

## Resolving a cited number

**GitHub shares one number sequence between issues and pull requests.** So `#412` may be a PR, and gaps in the ticket sequence mean nothing. Before treating a cited number as load-bearing, resolve it and confirm the title matches the claimed purpose:

```bash
gh issue view 412 --repo "$REPO" --json number,title,state,labels,url
```

**Resolve by number, never by searching titles.** A search over title and body readily returns a *different* issue that merely mentions the one you want: a follow-up, a spin-off, a duplicate report. Linking the wrong number closes someone else's ticket on merge, and unlike a missing link that failure is invisible afterward.

## Reporting a ticket

- **Discussing or updating an existing ticket: show its full URL**, `https://github.com/<owner>/<name>/issues/<number>`, once per ticket per message. A bare `#23` is not clickable in a terminal, and opening the issue is almost always the reader's next action. This covers status reports, review findings, triage output, and the confirmation line after editing an issue.
- **Reporting a ticket you just created: give the branch name and nothing else.** That is the one thing the reader acts on, since `/pr:start` consumes it. The title, labels, assignee and URL are all one click away and were not asked for.
