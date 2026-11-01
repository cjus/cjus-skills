# remote-build: apply's summary reports the result, not the plan

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/117

## Changes

- `apply` builds its summary from what it did (`applied()`), not from the read-only plan
  (`summary_of()`, which `plan` still prints):
  - `stack` is the CloudFormation status after the last deploy (`deploy()` now returns it), not
    `will be created`.
  - Each launch profile's `image` is `built <ami>` or `reused <ami>`, with the `launch_version`
    the config now pins, not `bake` or `reuse`.
  - `removed_profiles` and `retired_images` say what this run dropped and deleted.
  - `alerts` reads the topic's subscriptions (`sns list-subscriptions-by-topic`): `confirmed`,
    `pending` (the email still needs confirming), `none` (no `--alert-email`) or `unknown`
    (the read failed; apply still succeeds).
- The simulated cloud reports `CREATE_COMPLETE` for a new stack and keeps an email subscription
  pending until a test confirms it. Three new tests cover a first apply, a re-run after
  confirming, a rebake, a dropped profile, an unreadable subscription and no alert email.
  Mutation checks: restoring the plan as the result, the fixed alert reminder, or the pre-apply
  stack status each fail a test.
- The operator guide's quick start describes each summary field. Version 0.4.1.
