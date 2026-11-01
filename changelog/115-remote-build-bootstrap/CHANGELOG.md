# remote-build: bootstrap the AWS prerequisites in one command

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/115

## Changes

- New `scripts/bootstrap.py`, run by the operator with an admin AWS profile:
  - `plan` reads only: admin identity, each type's architecture, a default-VPC subnet whose
    zone offers every type, the operator's address, existing stack and images, running workers.
  - `apply` creates the SSH key if missing, deploys stack `remote-build-<owner>` (security group
    from the operator's /32, janitor Lambda with a five-minute schedule, 30-day log group, error
    and silence alarms, optional email subscription), bakes one image per launch profile, then
    adds a launch template per profile and the operator role. It writes a daily profile that
    assumes the role with the admin profile as `source_profile`, the known-hosts file and the
    private config, proves the policy with dry runs, and runs the janitor test before setting
    `janitor_confirmed`. Re-runs remember choices, reuse available images, keep template IDs
    through a rebake (new version), retire replaced images, keep config tunables, and refuse
    image changes while workers run. Refuses another owner's config or an unmanaged profile
    before changing anything.
  - `teardown --confirm <owner>` refuses while workers run, then deletes the stack, images and
    snapshots, the managed profile section, config, known hosts and this owner's state only.
  - `template` prints the stack offline with placeholder IDs.
- New `scripts/aws/provision.sh` and `scripts/aws/janitor.py`: the image and janitor code,
  shared by bootstrap and the manual steps. `RUST_TOOLCHAINS` preinstalls pinned toolchains.
- `setup`: a missing config now points to `bootstrap.py apply` (`#quick-start-bootstrap`); the
  janitor check mentions bootstrap's test.
- Setup skill: recommends bootstrap, collects the five choices, may run `plan` and `template`,
  hands the operator the `apply` command; still never runs `apply`, `teardown` or AWS changes.
- Operator guide: two paths, the trade-offs kept on purpose, quick start, re-run table,
  teardown, and "Make it yours" (flags and config first, then custom versions: fork, rename,
  set homepage, install, where each behaviour lives, invariants the client relies on). Manual
  steps unchanged except steps 6 and 9 use the shipped files.
- README: one-command setup and "Make it yours" sections. AWS, config, security, troubleshooting
  (bootstrap table), walkthrough and contract updated. Root README catalog row updated.
- Review against real AWS behaviour, fixed: provisioning waits for first-boot jobs and the dpkg
  lock, runs non-interactively with stdin closed (copied first, `DEBIAN_FRONTEND` passed through
  sudo, existing config files kept); a stack left in `REVIEW_IN_PROGRESS` is deployed over;
  snapshot deletion retries while deregistration releases it; teardown waits for terminating
  instances before deleting the stack; the security group has no fixed name, so a VPC change can
  replace it; the operator policy denies overriding the template's image, network or key pair;
  the janitor test boots a worker as the client does, logs in as `builder`, and counts only a
  client-initiated termination; a failed address lookup asks for `--cidr`.
- Tests: `tests/test_bootstrap.py`, 23 tests against a simulated cloud that evaluates the
  deployed operator policy and runs the janitor between polls. CI runs it. Version 0.4.0.
