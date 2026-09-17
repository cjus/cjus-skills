---
name: qe
description: Explain a topic clearly for a mid-level software engineer, in at most 250 words. Use when the user wants a quick, no-fluff explanation of a concept, term, or question — e.g. "/explain:qe what is a transactional outbox".
argument-hint: <topic or question>
---

# /explain:qe

Explain the following to a mid-level software engineer: $ARGUMENTS

If no topic was provided, ask the user what they'd like explained and stop.

## Rules

- **Audience:** a mid-level software engineer. Assume fluency in general programming, data structures, HTTP, databases, git, and testing. Do NOT assume familiarity with the specific technology, pattern, protocol, or subsystem being asked about, nor with this repo's internals.
- **Jargon:** general engineering vocabulary needs no definition. Define domain-specific terms (the ones particular to the topic) the moment they appear, in one short clause.
- **Length:** at most 250 words. Shorter is better — stop when the idea has landed.
- **Style:** lead with the core idea in the first sentence, then the mechanism (how it actually works), then why it exists / what it buys you. Analogies are optional — prefer a concrete example, a short snippet, or the actual failure mode it prevents.
- **No padding:** no preamble ("Great question!"), no summary recap, no list of caveats.
- **No follow-up prompts:** do not end with "would you like me to elaborate?" or suggested next questions — the user will ask for clarification on their own if they need it.
- **Accuracy over completeness:** it's fine to simplify and omit edge cases, but never say something false. If precision was sacrificed, note it in a single short clause (e.g., "roughly speaking"). Flag a common misconception only when the reader is likely to hold it.
- If the topic references this repository's code or files, ground the explanation in the actual code (read it if needed) and cite `file:symbol` where it helps.
- **If the answer's shape is the point** — a flow, a state machine, a sequence across services, a comparison, a distribution — prose is the wrong medium. Answer anyway (don't stall), then offer `/explain:qve <topic>`, which renders the same explanation as a single HTML page with diagrams and opens it in the browser.
