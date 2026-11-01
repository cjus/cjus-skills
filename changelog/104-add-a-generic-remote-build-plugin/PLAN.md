# Add a generic remote-build plugin

Start date: 2026-11-01 UTC

## Overview

Implement issue #104: a generic AWS-first remote Linux build/test plugin with a shared CLI,
thin agent skills, private configuration/state, durable source-bound jobs and safe teardown.
The objective is fixed for this branch; live cloud provisioning is outside authorization.

## Plan

- [x] Inspect repository plugin, marketplace and PR conventions.
- [x] Implement versioned lifecycle, immutable snapshots and durable worker jobs.
- [x] Document config, security, AWS prerequisites and Claude Code workflow.
- [x] Add offline tests and CI.
- [x] Complete local validation and privacy review.
- [x] Publish draft PR #105 and inspect initial CI.
- [x] Verify CI after pinning an available Python 3.9 runner.
- [x] Repair internal review findings and verify warm agent-owned Rust sessions.
- [x] Complete independent delta review (APPROVE).

## Deferred triage

No scheduled follow-up work. Optional extensions were dropped from this branch, with rationale
recorded in the PR summary. Operator infrastructure and separately authorized live validation
remain documented setup prerequisites; no live infrastructure changes were made.
