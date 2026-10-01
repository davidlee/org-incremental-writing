# Notes SL-002: Placement and vocabulary

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Design triage (2026-10-01, exploring)

Constraining governance: ADR-004 (allocation cases, no gap → stop, core owns
arithmetic), ADR-001..003, POL-002 (append-rank folds into one allocator),
STD-001 (literal pins, killed guards), STD-004 (refusals, naming), DEC-002
(`org-iw-queues` plist open to new keys). Evidence: `research/research.md`.

Shaping decisions carried in:
- One core allocator over (rest, depth) replaces `org-iw-core-append-rank`;
  Add, Continue and SL-003 move share it (POL-002, ADR-004 § 6).
- "Already last" stops being a Continue special case: it is REQ-010's
  general no-op (target already at the computed depth).
- No-gap refusal wording names redistribution as not yet available (RFC-001
  slice 2); SL-006 replaces the refusal with the hand-off.

Open design questions (tracked as `inq-*` in the design run):
- Placement spec representation, notably an exact fraction (floats misround
  under `floor`: research cross-thread finding).
- Vocabulary config keys and the standard defaults' depths (PRD-001 OQ-3).
- Chooser UI and how the default and chooser commands are bound.
- Add-at-placement entry point (prefix argument vs separate command).
- Continue message order: empty vs target-missing vs sole entry.
- Where invalid vocabulary config is refused.

Risks:
- Hot-spot exhaustion near the front ("after 2" halves one gap per use;
  about 10 uses at spacing 1024, ADR-004 negative consequence). Until SL-006
  the user sees a refusal with no remedy except hand-editing ranks.
- Chooser tests in batch block on stdin if a prompt escapes
  (mem.fact.emacs.batch-test-gotchas).

Assumptions:
- Remove in the Continue chooser waits for SL-003's remove (brief allows it
  "alongside" Continue; it is a distinct action).

Evidence (2026-10-01, python simulation of ADR-004 allocation, spacing 1024,
queue at 1024·i, always Continue the front): a single fixed placement used
every time — "after 2" or "halfway" — exhausts its gap after 11 Continues,
for queue sizes 5, 10, 30 and 100 alike (each insertion splits the gap the
previous one left). A random mix of after-2 / halfway / end lasted 41–5911
Continues. Tail rotation never exhausts. So the default placement decides
whether exhaustion is occasional or routine before SL-006 exists.

## Design review (2026-10-01)

RV-003 (`doctrine review show RV-003`): adversarial agent pass, 2 rounds, 9
findings (1 major, 7 minor, 1 nit), all fix-now and verified by the raiser.
The reviewer fuzzed a prototype of the § 5.2 core contract over 20,000 cases
with no failures. User rulings: F-1 (RET = default; UIs may list it first),
F-5 (Add's prompt defaults to the queue default; DEC-011 amended), F-8
(small-queue Later behaviour accepted, pinned by a test).

Further pass: none needed before planning. The core contract was checked by
an independent prototype and the remaining risk is interaction quality,
which the VH trial covers. Probe targets during implementation (tests carry
them): the precedence-ordered property checker and its self-test (§ 9), and
refusal-before-prompt in the interactive specs.

Tooling note: `doctrine design apply` refused review policy
`adversarial-then-human` ("payload label term is 22 bytes, over the 16-byte
admission bound"), although the contract lists it. The run stayed human-only;
the adversarial pass is RV-003.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-01 · design locked · 869915c (design work uncommitted)

### Produced
- design.md locked (run dr-01a0f578, rev 36); research/research.md; slice scope updated
- RV-003 — adversarial design review, 9 findings, all verified
- selectors: org-iw-core.el, org-iw.el, test/org-iw-core-test.el, test/org-iw-test.el, README.md

### Learned
- EVD-002 — repeated fixed placement exhausts its gap in ~11 Continues
- mem.fact.emacs.completing-read-default-bubbles — UIs float DEF to the top
- mem.pattern.doctrine.design-review-gate-gotchas — policy label bound, att- section review, routes before lock

### Open
- DEC-007 — placement forms (after / fraction / percent / end)
- DEC-008 — :placements / :default config; global defcustoms
- DEC-009 — standard Soon/Later/End, default End; settles PRD-001 OQ-3 (PRD text updated at reconcile)
- DEC-010 — spacing stays 1024
- DEC-011 — prefix + completing-read surface (amended per RV-003 F-1, F-5)
- ISS-001 — Continue docstring half fixed in passing; put-rank half stays open
