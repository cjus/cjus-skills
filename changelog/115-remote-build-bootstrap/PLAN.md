# remote-build: bootstrap the AWS prerequisites in one command

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/115

## Overview

Setting remote-build up took twelve manual steps of copy-pasted AWS commands, even for an
operator whose credentials can create everything. Add an operator-run `bootstrap.py` that does
the mechanical work from five decisions, tests what it built, and writes the config; keep the
manual steps as the reference; document how to adapt the plugin or make a custom version.

## Plan

- [x] `scripts/bootstrap.py`: `plan` (read-only), `apply`, `teardown`, `template` (offline).
- [x] One CloudFormation stack rendered in Python: security group, janitor Lambda with schedule,
      log group and alarms, launch template per profile, operator role with the step-8 policy.
- [x] Image bake per profile: host key through console output, `scripts/aws/provision.sh`,
      builder checks, image; cleanup on failure, `--keep-on-failure` for debugging.
- [x] Daily profile assumes the operator role through `source_profile` (no access key).
- [x] Dry-run policy checks and the janitor test; `janitor_confirmed` only after it passes.
- [x] Safe re-runs: reuse images, rebake keeps template IDs, type changes without a bake,
      leftovers removed, refusals before any change, workers block image changes.
- [x] Teardown that removes only this owner's resources and files.
- [x] Janitor and provisioning script shipped as files; manual steps 6 and 9 use them.
- [x] `setup` points a missing config at bootstrap; skill runs only `plan`/`template`.
- [x] Guide leads with the quick start; "Make it yours" in guide and README; references updated.
- [x] Offline tests with a simulated cloud; CI runs them. Version 0.4.0.
