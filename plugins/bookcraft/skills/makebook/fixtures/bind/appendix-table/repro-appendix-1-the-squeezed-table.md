# The Squeezed Table

Prose.

| Term | What it means in practice |
|---|---|
| Denormalization | Deliberately storing the same fact in more than one place so that a read which would otherwise join several tables can be served from one, at the cost of keeping the copies in step whenever the fact changes. |
| Characteristically | A word chosen here only because it is long, sitting beside a description long enough that the browser wants to give its column most of the measure and leave this one short of its own longest word. |
| Referential | Every foreign key names a row that exists, which the database enforces on every insert, update and delete that touches either side of the relationship between the two tables. |
