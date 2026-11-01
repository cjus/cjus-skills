# Add a generic remote-build plugin

Start date: 2026-11-01 UTC

## Overview

Implement issue #104: a generic AWS-first remote Linux build/test plugin with a shared CLI,
thin agent skills, private configuration/state, durable source-bound jobs and safe teardown.
The objective is fixed for this branch; live cloud provisioning is outside authorization.

## Plan

- [x] Inspect repository plugin, marketplace and PR conventions.
- [x] Implement versioned lifecycle, immutable snapshots and durable worker jobs.
- [x] Document config, security, AWS prerequisites and Codex adapter.
- [x] Add offline tests and CI.
- [x] Complete local validation and privacy review.
- [x] Publish draft PR #105 and inspect initial CI.
- [ ] Verify CI after pinning an available Python 3.9 runner.

## Deferred

Retained EBS caches, binary artifact download, additional providers and MCP are outside v1.
Independent janitor deployment and a separately approved live smoke test belong to operator
setup; no live infrastructure changes are made by this implementation.
