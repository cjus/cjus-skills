# Remote-build plugin

Issue: https://github.com/cjus/cjus-skills/issues/104

Local agents can now prepare an immutable source snapshot, submit a durable Linux build/test
job to an explicitly approved AWS worker, reconnect for its result, and tear down only a
verified owned instance. The five skills share one Python CLI and contract v1; Codex uses
that CLI through an explicit plugin path.

## Validation

- 20 offline tests pass on Python 3.9.6 and 3.14.2, including executable fake AWS/SSH CLI
  integration, launch uncertainty, auth failures, ownership, exclusions, source mismatch,
  disconnect recovery, command failure, job expiry and bounded logs.
- Strict marketplace and plugin validation pass. The plugin validator reports an advisory
  missing-icon warning; no icon is required by the existing repository plugin convention.
- Repository citation check and staged whitespace check pass.
- Skill-creator quick validation could not run because its optional PyYAML dependency is
  unavailable. No dependency was installed. Plugin manifest validation is independently green.
- New code, examples, tests and PR text were reviewed for credentials, real infrastructure
  identifiers, personal paths, consumer repository names and private logs; none were included.

## Limits and review focus

Live AWS/SSH infrastructure has not been exercised. The operator must independently provision
and verify the pinned image/template, host identity, IAM/network controls and expiry janitor.
The CLI checks a janitor declaration, not deployment. Count checks are local plus owner-tag
reads, not a distributed lease or billing cap. V1 retains cache only for the session and
requires EBS deletion on termination. Each job gets isolated Cargo directories. Binary
artifact downloads and retained EBS cache are deferred.

Review launch/termination ownership, uncertain-outcome recovery, source filtering and worker
process handling first. Before merge, the operator must run `/pr:close` per repository
workflow. This draft does not approve or merge itself and publishes no release tag.
