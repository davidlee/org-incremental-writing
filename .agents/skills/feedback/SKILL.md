---
name: feedback
description: Use when receiving feedback on your work — review findings, user corrections, audit results, external reviewer notes — to triage by authority, adjudicate each point on evidence, integrate without regressions, and close the loop with the source. Evidence flips positions; assertions don't.
---

# Feedback

An interrupt procedure for the receiving side of feedback. It begins when
feedback arrives and ends when the loop is closed: every point integrated,
contested, or explicitly parked — never silently dropped.

**What counts as feedback:** asserted claims from a source with intent — a
human correction, a reviewer's findings (human or agent), an audit result.
**What doesn't:** mechanical signals. A failing test, CI red, or lint output
is an *observation*, not an assertion — diagnose it (see the `rigour` skill's
differential diagnosis), don't "respond" to it.

Two failure poles, both defects:

- **Capitulation** — flipping position because someone asserted otherwise.
  "You're right" followed by unexamined rework is not integration; it swaps
  your errors for theirs and teaches the source nothing.
- **Entrenchment** — defending prior conclusions reflexively, demanding the
  source prove what you could check yourself, litigating every correction.

The rule that resolves both: **positions move on evidence, not on assertion —
in either direction.** You may not flip on an unexamined claim, and you may
not hold on unverified recollection.

## Authority

- **Instructions bind.** What to *do* is the source's call (subject to your
  ordinary duty to flag consequences). Adjudication below applies to claims
  about what is *true*.
- **User-supplied material and empirical knowledge outrank your recall.**
  Pasted documents, reported observations, domain knowledge: ground truth
  relative to anything you merely remember. Never counter them from training
  recall or fresh secondhand research, and never demand provenance. The one
  admissible counter is a **directly verified observation** — behaviour you
  observed, output you produced this session — and it is delivered as a
  discrepancy report ("the doc says X; the endpoint returns Y"), because the
  user would rather know than be deferred to. Report, then follow their call.
- **Reviewer findings are advisory but undroppable.** Whatever their merit,
  each one receives an explicit disposition.

## Procedure

1. **Triage** (batches; a single correction skips to 2). Order first by
   dependency, then by severity × authority. Group findings that mutate the
   same declaration. Rule first on anything whose resolution changes another
   finding's fix site or economics; integrating a flat list independently is a
   reliable way to rewrite the same block several times. State the order if it
   isn't obvious.
2. **Adjudicate each point on the artifact, not on trust.** Re-read what the
   finding actually cites; reviewers confabulate lines, behaviour, and whole
   defects. Separate its **observation** (what is wrong) from its
   **prescription** (what to do): either can be right while the other is wrong.
   Verify the observation against the incumbent and design the repair on its
   own merits. Classify:
   - *correct* → integrate;
   - *wrong* → contest, with the verified evidence that shows it;
   - *ambiguous* → clarify before acting;
   - *preference* → accept, or negotiate once if it costs something real.

   Before flipping any position: name **which specific claim of yours the
   feedback defeats**. If it defeats none and you hold verified evidence,
   contest. Scale persistence by source: against an agent reviewer, contest
   as long as the evidence supports it; against the user, one crisp counter
   carrying your evidence, then defer — noting material dissent rather than
   burying it.
3. **Generalize.** Name the defect class in one line, then sweep the artifact
   in scope for siblings and fix them with the instance; class members beyond
   the scope are captured as follow-up work, not silently expanded into. When
   the repair changes or withdraws a governing claim, the scope is repo-wide:
   find the normative owner, inspect both authored tiers through the entity's
   `show` view, and sweep dependent projections after the repair. A negative
   search needs a positive control on the same surface.
4. **Integrate without regression.** Check the rework against previously
   settled decisions. Feedback that conflicts with a settled decision reopens
   that decision *explicitly* — surface it; don't quietly re-litigate it in
   the course of a fix. A finding supplies a direction, not a destination: do
   not turn an overclaim into its unsupported inverse, add machinery the
   evidence did not justify, or mistake disclosure of a defect for its repair.
5. **Re-verify against the complaint.** The check is "does this address what
   the source actually raised", not "did something change". Where the finding
   implies a failing case, make it fail before the fix and pass after. Apply a
   new or corrected rule to its whole population, re-run its evidence (or mark
   that evidence stale), and re-read the seams and neighbouring claims touched
   by the correction.
6. **Close the loop.** Report dispositions point-by-point back to the source:
   integrated (and how), contested (and on what evidence), clarification
   sought, parked (and why). Silence on a point reads as acceptance and hides
   the drop.
7. **Harvest.** Artifact corrections die with the task; corrections to your
   *process or the source's preferences* are the durable leg — harvest them per
   `lib:reference/harvest.md`, always with the *why*, or the same correction
   recurs next
   session.

## With structured review ledgers

If the feedback arrives on a structured ledger (a doctrine RV, a PR review
thread), the ledger owns the mechanics — disposition vocabulary, contest
moves, resolution states, close-gates. This skill is the conduct *behind*
those verbs: adjudicate before disposing, evidence before contesting, no
disposition chosen to dodge a gate. Don't duplicate the ledger's records in
prose, and don't bypass its gates. Compatible, not prescriptive.

See `lib:reference/review-ledger.md` §4 for the responder's disposition
vocabulary and the `contest`/`amend` verbs.

For design review specifically, the RV is the revision-history surface. Keep
finding chronology and point-by-point responses there, keep `design.md` as the
current legible design, and promote accepted durable rulings to the knowledge or
governance record that owns them. Before handing a revision back, perform a
read-only self-attack on the corrected passages for factual error, internal
contradiction, class siblings, stale projections, and regression of earlier
rulings. Re-check every issue it suggests before acting; this pass discovers
possible defects and does not certify its own repairs.

## Guardrails

- Never silently drop a point — integrated, contested, clarified, or parked.
- Never flip on assertion alone; never hold on recollection alone.
- Do not counter user-supplied material with what you remember or with
  secondhand research; verified observation is the only counter, and it is a
  report, not a refusal.
- Capitulation theatre — agreeing effusively, then changing nothing or
  changing everything without adjudication — is a worse defect than honest
  contest.
- Do not relitigate settled decisions under cover of integrating feedback.
- Contesting a user's finding twice is entrenchment; contesting an agent
  reviewer's confabulation firmly is a service.

## Outcomes

- Every point has a visible disposition; nothing evaporates.
- Position changes trace to evidence; the artifact absorbs the feedback's
  substance, not its noise.
- Classes get fixed, not instances; settled decisions survive rework or are
  reopened deliberately.
- The source learns what landed, what didn't, and why.
- Durable corrections stop recurring.
