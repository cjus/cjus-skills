bookcraft: add a primer profile and make it the default for new books

reference/primer.md is a standalone rule set for a primer chapter: teach, mention or leave as the outline decides, problem first, a device per concept, ceilings instead of bands, an assigned opening, and Sources and further reading last.
check-book.sh accepts primer: its own closing section, any number of sections, H3 and appendices, a 100-word paragraph ceiling that reports, a mark required above the first paragraph, and a refusal of primer with overview.
check-book.sh reports a chapter whose paragraphs cluster near the limit, under every profile.
check-provenance.sh stops its walk at the primer's closing section.
createbook/SKILL.md makes primer the default, adds § Under the primer profile, a primer book.json template, primer sizing and read time, and primer-aware prompt items.
updatebook/SKILL.md edits a primer under primer.md and qualifies its handbook-only rules.
fixtures/primer and fixtures/primer-failures, with manifest rows.
README describes three profiles, NOTES.md records the trial and the decisions, and the plugin moves to 1.18.0.
The plan folder holds the plan, changelog, PR summary and both reviews.
