apply review wording fixes and add close artifacts for the no-jq guard fix

- hooks README: say a whole no-jq payload gets the decision it always did, not jq parity
- hooks README: explain each mass-failure shape per suite section, and resolve through CLAUDE_PROJECT_DIR
- guard hook: name the only-one-command-key assumption and state the blind spot as "command read whole"
- guard suite: match the blind-spot comment to the hook's wording
- changelog: condense to decisions and evidence, keeping every timestamp
- add pr-summary, the pre-test review and the close-gate review
