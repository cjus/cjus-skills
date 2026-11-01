# remote-build: per-repository launch profiles

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/108

## Overview

Let each repository choose its own EC2 type and launch template, and run its own worker
alongside other repositories' workers. Stacked on #106's branch.

## Plan

- [x] Private config v2 with named launch profiles and `max_workers`; refuse v1 configs.
- [x] Committed `.remote-build.json` selecting a profile and type, validated before any AWS call.
- [x] Per-checkout state, lock and `remote-build:project` tag; per-project worker check and `max_workers`.
- [x] Session binds only its own selection; launch lock across projects on one client.
- [x] Offline tests, including two repositories with different profiles running concurrently.
- [x] Contract v2, config, AWS, walkthrough, troubleshooting, security, README, five skills; 0.2.0.
