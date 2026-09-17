# explain

Two Claude Code skills that explain a thing to a working engineer: one in prose, one as a page you can look at.

They are the same job with the same audience and the same honesty bar, differing only in medium. `/explain:qe` answers in at most 250 words. `/explain:qve` answers as a single self-contained HTML page with diagrams and opens it in your browser, for the cases where the answer's *shape* is the point.

---

## Contents

- [Install](#install)
- [`/explain:qe`](#explainqe)
- [`/explain:qve`](#explainqve)
- [Choosing between them](#choosing-between-them)
- [What ships here](#what-ships-here)

---

## Install

```bash
claude plugin marketplace add cjus/cjus-skills
claude plugin install explain@cjus-skills
```

Restart Claude Code. Both slash commands become available. There is no setup step; neither skill needs third-party packages.

**Plugin skills are namespaced by their plugin**, so you invoke them as `/explain:qe` and `/explain:qve`. A bare `/qe` does not resolve unless you happen to have a separate skill of that name. The prefix is what keeps two plugins from fighting over a common name; this page writes it out in every command you would type, and drops it when referring to a skill by name in prose.

---

## `/explain:qe`

```
/explain:qe what is a transactional outbox
```

At most 250 words, aimed at a mid-level software engineer. It assumes fluency in general programming, data structures, HTTP, databases, git and testing, and assumes nothing about the specific technology you asked about.

The shape is fixed: the core idea in the first sentence, then the mechanism, then why it exists. No preamble, no recap, no "would you like me to elaborate?". Domain-specific terms get defined the moment they appear, in a clause.

It simplifies freely but will not say anything false. Where precision was traded away, it says so in a short clause rather than leaving you with a clean lie.

If the topic touches code in the current repo, it reads the code and grounds the explanation in it, citing `file:symbol`.

---

## `/explain:qve`

```
/explain:qve how does the gallery build pipeline work
/explain:qve raft consensus
```

Quick visual explain. Builds one self-contained HTML page — Mermaid diagrams, hand-authored SVG where the shape is geometric, and a small set of layout components for steps, comparisons and magnitude — then opens it.

It inherits `/explain:qe`'s audience and voice rules in full. What it adds is the judgement about when a picture carries the idea better than a sentence, and the discipline to drop any visual it cannot justify in one line.

**It will refuse rather than decorate.** If the topic has no shape worth drawing, it says so and points you back at `/explain:qe`. A page of prose in a dark wrapper with one ornamental box-and-arrow diagram is worse than a good paragraph.

Pages are written to `$HOME/.claude/qve`, outside the plugin directory so they survive plugin updates.

### Rendering notes

Mermaid renders from a CDN when the page is opened, so viewing needs network. If the CDN is unreachable the diagram source stays visible — degraded, not broken.

After writing a page, the skill checks the diagrams actually rendered, because a Mermaid parse error shows up as a red box in the browser and nothing else reports it. If it cannot run that check, it tells you rendering was unverified rather than implying it passed.

---

## Choosing between them

| You want | Use |
| --- | --- |
| A definition, a mechanism, a "what is X" | `/explain:qe` |
| A flow, a pipeline, a state machine | `/explain:qve` |
| A sequence across several services | `/explain:qve` |
| A comparison, a distribution, a tradeoff with shape | `/explain:qve` |
| An answer you will paste into a PR comment | `/explain:qe` |
| An answer you will keep open on a second monitor | `/explain:qve` |

When in doubt, start with `/explain:qe`. It is faster, and it will tell you when the answer wanted a picture.

---

## What ships here

```
plugins/explain/
  .claude-plugin/plugin.json
  README.md
  skills/qe/SKILL.md
  skills/qve/SKILL.md
  skills/qve/references/page-template.html
```
