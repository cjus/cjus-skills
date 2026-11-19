bookcraft: skip fenced lines in the block-quote check and warn on stray bound files

check-book.sh's narration block-quote check now skips fenced lines, as the guide callout check already did, so a shell session's "> " prompt in a code block no longer fails the book.
fixtures/fence chapter 2 carries a fenced shell session, which fails on main and passes here.
book_model.strays names an unnumbered chapter-kind file in a folder whose other chapters are numbered, unless the book declares labels.
The binder warns for each stray it binds, saying what it was bound as and that exclude drops it.
fixtures/book-model covers a stray, an excluded file, a labels book and a plain notes folder.
createbook/SKILL.md and makebook/SKILL.md document both changes, and the plugin moves to 1.17.1.
The plan folder holds the plan, changelog, PR summary and review.
