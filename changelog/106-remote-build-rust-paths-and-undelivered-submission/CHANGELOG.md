# remote-build: Rust paths and undelivered submissions

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/106

## Changes

- The credential-assignment screen takes `=` or a lone `:` as the separator, so `Token::Comment(...)`
  and similar paths no longer refuse the whole snapshot. Real assignments are still refused.
- The worker answers a status request for a job it has no record of under the submission lock,
  and leaves an empty directory for that ID so a late-arriving submission is refused. A fence
  uses no job slot.
- The client treats that `unknown` for its pending submission as final: it clears `pending_job`,
  drops the ID from the session and keeps the result record, so the next `run` is accepted on
  the same worker. `unknown` for any other job still stops reconciliation.
- Tests: Rust paths accepted, assignments refused, released submission, delivered-job `unknown`
  still refused, worker fence, and a CLI round trip through a fake ssh that fails once with 255.
- Docs: contract v1 recovery and source screening, troubleshooting, security, status skill.
- Version 0.1.1.
