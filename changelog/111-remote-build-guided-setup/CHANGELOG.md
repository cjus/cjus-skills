# remote-build: guided setup

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/111

## Changes

- New `reference/operator-guide.md`: twelve steps covering every prerequisite (profiles, SSH key,
  security group, build machine, host key through `get-console-output`, worker image, launch
  template, IAM policy verified by `run-instances --dry-run`, janitor Lambda with alarms and an
  expiry test, private config, repository selection, smoke test) and teardown. Each step ends
  with a check. The image disables cloud-init and uses MAC-independent DHCP because the client
  disables the instance metadata service at launch. Marked as not validated against live AWS.
- `setup` is now a checklist: tools, config, config permissions and location, AWS
  authentication, each launch profile, SSH identity, known hosts, janitor declaration and
  repository selection, each `ok`, `fail` or `blocked`, with `next` and a guide link (web and
  installed). `ready` and a top-level `next`; exits 0 only when ready. Still prints no account
  identity or key paths.
- Config parsing is split from the janitor and SSH file checks so setup can report them
  separately. Other commands refuse a missing config by name and point to setup.
- The setup skill presents the checklist, walks the first failing step from the guide, may write
  the private config from values the operator gives, and never runs the guide's AWS commands.
- Tests: missing config, ready, separate gaps, authentication failure blocking templates, and
  every linked guide anchor existing. Fake AWS can fail one operation on request.
- Docs point to the guide; contract setup row describes the checklist. Version 0.3.0.
