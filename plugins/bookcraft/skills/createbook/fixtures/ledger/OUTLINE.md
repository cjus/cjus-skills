# Ledger fixture

A fixture for `check-provenance.sh --ledger-only`. The table below is the source
ledger `createbook/SKILL.md` § 2 describes, carrying one row of each shape the
check can reach.

## Source ledger

| Source | Re-openable | What the book owes it | Paid by |
|---|---|---|---|
| `sources/handbook.md` § What The Grain Is | Yes | The definition of the grain | 1 |
| `sources/handbook.md` Q3 | Yes | The worked multiple-choice item | 1 |
| `sources/handbook.md` § Nothing Like This | Yes | A heading the source does not carry | 2 |
| `sources/handbook.md` Q9 | Yes | An item the source does not define | 2 |
| `sources/missing.md` | Yes | A file that is not on disk | 2 |
| Search terms: star schema tutorials | No | Background reading only | 1 |
| `sources/handbook.md` p. 6 | Yes | A page locator aimed at a markdown source | 3 |

## Chapter list

| Chapter | Title |
|---|---|
| 1 | The grain |
| 2 | Indexes |
