close the fixture-health branch, with the review's fixes

Closing artifacts for #6, plus the four changes the close review asked for.

The runner's manifest no longer accepts a row that names no required output. A
row with an empty fourth field asserted the exit code and nothing else, which is
the exact weakness the runner exists to remove, so it now fails rather than
degrading quietly.

The manifest gained a ! prefix meaning must-NOT-contain. The provenance fixture
documents that a run reporting anything against its chapter 1 is a regression,
and only an absence assertion can hold that; the row now also asserts the REVIEW
line, where before it asserted half of what the fixture claims.

The workflow declares permissions: contents: read. It is the repo's first, so it
sets the default later ones get compared against, and nothing in it writes.

"Linux cannot fail the branch" was asserted in three documents and is too strong.
continue-on-error keeps the workflow run's conclusion success, but the ubuntu job
and its check run both report failure, and gh pr checks reads check runs. So a
Linux-only failure shows as a red check and will halt this plugin's own CI gate.
Verified against the probe commit: check run failure, run conclusion success. The
workflow header and the root README now say that instead.

One review finding was not acted on. Two citations flagged as cross-repo are #26,
which origin/main cites a dozen times as this repo's own pre-rebuild issue
number; the numbering restarted when the tree was rebuilt. Left as found, since
every other folder under changelog/ reads the same way.

Deferred, untriaged into tickets: a bash-invalid `command -v -a jq` in the
jq-unrunnable probe's pre-existing half, which falls through to hardcoded
candidates and finds a working jq anyway; and check-references.sh, the third
checker, which no fixture exercises at all.
