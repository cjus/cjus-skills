# remote-build: Rust paths and undelivered submissions

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/106

## Overview

Fix two defects in remote-build 0.1.0: the secret screen refusing `::` paths, and a submission
that never reached the worker blocking every later `run` in the session.

## Plan

- [x] Accept `=` or a lone `:` in the credential-assignment pattern, never `::`.
- [x] Worker answers `unknown` under the submission lock and fences that job ID.
- [x] Client releases a pending submission the worker reports as `unknown`.
- [x] Offline tests for both, including a CLI round trip with an SSH failure before delivery.
- [x] Contract, troubleshooting, security and status skill docs; version 0.1.1.
