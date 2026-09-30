---
name: elicit
description: Use when running a value-elicitation session — surfacing and asking the next worthwhile pairwise value questions, reviewing suspect anchors, or calibrating value evidence with a human via `doctrine compare elicit`.
---

# Elicit

You are the **curator** half of the queue/curator split. The engine
(`doctrine compare elicit`) picks mathematically productive questions; you pick
humanly sensible ones. Curate — filter, reframe, sequence, translate. Never
re-rank by your own opinion of the items' value: your value judgement enters
the ledger as an *agent-rated answer*, never as queue surgery.

The queue is read-only; the comparison ledger is the durable state. The
CLI is the source of truth for flags: `doctrine compare --help`.

## Fetch

Run `doctrine compare elicit --json`; see `doctrine compare elicit --help` for
`--depth`/`--kind`.

Entries share a spine — `rank / kind / guaranteed_yield / guaranteed_impact /
score / reasons / ask`. Two kinds, different `yield_basis` semantics:

- `comparison` — yield is the min over **order-bearing** answers
  (prefer-a/prefer-b/equal). `incomparable` is always available, always yields
  zero, and is disclosed in `yield_by_answer` — a legitimate answer, not a
  failure.
- `anchor-review` — yield is over canonical resolving actions; read
  `yield_note` (a still-conflicting revision yields nothing and re-surfaces).

See `doctrine compare elicit --help` for the `--kind` values and `--limit`.

## Curate the batch

- Session size 5–10 questions; stop before fatigue degrades answers.
- **Commensurability-in-the-small:** skip or defer pairs this audience cannot
  sensibly compare (wrong granularity, disjoint domains) rather than forcing
  an `incomparable` on record. Skipping costs nothing — the queue re-offers.
- Audience fit: stakeholder sessions get product-shaped pairs; team sessions
  take anything admissible. Tag with `--audience` at record time.
- Frame: `equal-effort` ("if effort were equal, which matters more?") is the
  default; `prefer-first` ("under a binding cutoff, which do you keep?") is a
  priority-domain row, not value-bearing — use it only when the cutoff is real.

## Present questions

- Say what an answer buys in plain terms — "settles N comparisons whichever
  way you answer" — never the raw phrase *guaranteed yield*; show the
  per-answer breakdown when it varies. The floor excludes `incomparable`, so
  never claim unconditional progress.
- Offer `incomparable` without stigma; repeated incomparables are a signal the
  pairing or audience is wrong — adapt the session, don't push.
- An `anchor-review` entry is not a versus question. Present it as: one
  authored value (`subject.id`, `subject.anchor`) may be stale and is
  quarantining comparison evidence (`subject.conflict_pairs`,
  `subject.quarantined_rows`). The `ask.exits` map carries the exact command
  per answer (revise the anchor, or uphold it and supersede/withdraw rows).
- A participant annotated `projection masked by bare estimate` has no usable
  cost projection. The engine never ranks estimate questions (Phase E gate) —
  you may nominate one yourself: ask, then `doctrine estimate set`.

## Record answers

Copy the entry's `ask`; the answer leg is always the open capture surface:

```
doctrine compare record <A> <B> --prefer a|b | --equal | --incomparable
```

See `doctrine compare record --help` for the full flag surface.

Provenance stays honest: a human's answer is `--rater human`, always. Your own
judgements (when the human delegates) stay `--rater agent`.

## Refresh and stop

Re-run `elicit` after each batch — answers move bounds, the queue re-derives.
State footer semantics, worth repeating to the human accurately:

- `candidates` — questions remain worth asking.
- `stalled` — no single question guarantees progress at this depth; **not**
  stability. A bridge question may still exist.
- `stable` — value-for-effort **order among the current top-K members** is
  settled. Never present this as "priority settled": membership vs the field
  below the line, risk, leverage, and sequencing may still move the final
  recommendation.
