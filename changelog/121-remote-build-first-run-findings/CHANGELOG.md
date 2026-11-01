# remote-build: findings from a first real run

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/121

## Changes

- **Publishing rule.** `security.md` gains "Publishing": tool output is private even when not
  secret. That covers the operator's address, subnet, VPC, AMI, template and instance IDs,
  account and IAM identity, and the alert email. It stays out of commits, PRs, issues, comments
  and committed docs; describe it generically. Every skill and the README point to it.
- **Subnets.**
  - Without a default VPC, `plan` and `apply` name the subnets that would work: an internet
    route in public mode, in a zone offering every type. They refuse until one is passed.
  - A `--subnet`, or the remembered subnet, is checked on every run before anything changes.
    Its zone must offer every type, and in public mode its route table (its own, else the
    VPC's main table) must send `0.0.0.0/0` to an internet gateway. Network ACLs aren't
    checked.
- **Long `apply`.** The setup skill and the guide say that `apply` outlives a `!` command's two
  foreground minutes and goes to the background, which is expected. In a plain terminal, use
  `tee`.
- **`.git`.** The contract, the run skill, the README and troubleshooting say snapshots never
  carry `.git`, so scripts and tests that ask git must handle a missing repository.
- **Result file.** `status --job` prints `result_file`, the private file holding the bounded
  log. The contract's table no longer says the log is printed.
- **Waiting.**
  - `status --job ID --wait` polls until the job leaves submitted/queued/running, or the
    session expires.
  - `down --wait` repeats until `terminated` or `absent`, for at most 15 minutes.
  - Both back off from 1 s to 20 s, and take and release the project lock on each poll, so
    other commands still run.
  - A command that finds the lock held still refuses at once.
- **Tests:**
  - three bootstrap tests: no default VPC (public and private modes, none usable), a bad
    `--subnet` refused before any change, a remembered subnet that lost its route
  - four client tests: CLI `status --wait` and `down --wait` with the result file, poll backoff
    and deadline, the lock released between polls, and a held lock refused at once
  - The simulated cloud gains default-VPC, subnet and route-table state.
  - Mutation checks: an always-routed subnet, candidates without the route filter, zones
    offering everything, no polling, no backoff cap, a lock that always waits, and a missing
    `result_file` each fail a test.
- Version 0.6.0.
