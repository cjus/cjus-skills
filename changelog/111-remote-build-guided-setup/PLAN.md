# remote-build: guided setup

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/111

## Overview

Make setup guide the operator through every prerequisite without doing the work: a
step-by-step operator guide, a checklist from `setup` that links each gap to its step, and a
setup skill that walks the first failing item.

## Plan

- [x] Operator guide with commands and a check per step, from local tools to teardown.
- [x] `setup` reports every check as ok, fail or blocked, with a next step and guide link.
- [x] Clear "no private config" refusal for the other commands.
- [x] Setup skill presents the checklist and walks the first failure; never runs AWS commands.
- [x] Tests: missing config, ready, separate gaps, authentication failure, guide anchors.
- [x] README, config, AWS, walkthrough, contract and troubleshooting point to the guide; 0.3.0.
