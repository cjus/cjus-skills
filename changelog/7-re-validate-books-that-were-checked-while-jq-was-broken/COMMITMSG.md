sort the silent grading downgrades from the loud one, and close out the branch

Two review rounds against the fixture table committed in 771be3e, plus the closing
artifacts.

The first round found the record overstated the bug. This changelog said fixtures/fence
"reported all three as off" under the stale binary and that "the checks were not being
run". Reproducing the degraded path — fixtures/fence with jq removed from PATH, the same
declared_*="" the broken binary produced — shows two of three off and the third fallen
back to inference, with the filename, ordering, heading and prose sweeps still running.
Corrected in CHANGELOG.md and recorded beside the operator's sentence in PLAN.md rather
than edited into their record of an earlier branch.

The second round found an error introduced by the first. Naming what a downgraded mode
skips, README.md listed the profile substitution alongside four silent degradations, but
a guide book graded under the narration rules does not slip through quietly: it fails on
every construct the profile exists to allow. guide-under-narration is that case and exits
1 on five lines, two paragraphs below where the text claimed otherwise. The warning now
sorts the silent case from the loud one.

- plugins/bookcraft/README.md: split the narration downgrade from the guide one; drop the
  duplicated statement of the table's path root
- CHANGELOG.md: correct the overstatement, frame the mode-line excerpt as the partial
  quote it is, add the 2026-09-23 entry for both review rounds, rewrap
- PLAN.md: record the correction beside the ticket narrative, frame the same excerpt, and
  file the review's two follow-ups under Deferred
- pr-summary-2026-09-23.md, pr-review-2026-09-23.md: closing artifacts

No executable code changed. All nine fixture exit codes, all three fixture runners and
check-citations.py verified green after the edits.
