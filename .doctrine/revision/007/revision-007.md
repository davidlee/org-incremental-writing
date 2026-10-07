# REV REV-007 — Save policy: consented save of modified buffers in redistribution

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

Amends the save policy for SL-006's redistribution (RV-014 F-3; user
chose option (a), 2026-10-07). Amended DEC-029 saves an already-modified
affected buffer when the single approval prompt names it and the user
answers yes. As written, ADR-002's save policy and REQ-021 AC2/AC4 say
an already-modified buffer is always left unsaved. PRD-001 § 4 ("never
saved by the package without the user's explicit resolution") and
REQ-019 AC3 already allow it, so they are not changed. Lands at SL-006
reconcile.

Two rows, each a modify.

**ADR-002, Decision, save-policy bullet.**

- Before: "Save policy: a buffer that was unmodified before the
  operation is saved after it. A buffer that was already modified is
  left unsaved, and the user is told the queue change is unsaved.
  Nothing is ever written to disk behind a live buffer."
- After: "Save policy: a buffer that was unmodified before the
  operation is saved after it. A buffer that was already modified is
  left unsaved, and the user is told the queue change is unsaved,
  unless the user explicitly agreed to save it in that operation's
  approval prompt, which names the buffer (redistribution, DEC-029).
  Nothing is ever written to disk behind a live buffer."
- Positive consequence "Unsaved writing is never lost or silently
  saved." stands.

**REQ-021, description and acceptance criteria 2 and 4.**

- Description, after: "A buffer that was clean before an operation is
  saved automatically after it; an already-modified buffer is left
  unsaved with a clear report that its queue change remains unsaved,
  unless the user explicitly agreed to save it in an approval prompt
  that names it; files are never written behind live buffers."
- AC2, after: "Operating on a dirty buffer leaves it modified and the
  user is told the queue change is unsaved, unless the operation's
  approval prompt named the buffer and the user agreed to save it."
- AC4, after: "Batch operations apply the same policy per file."
  (unchanged wording; the consent exception applies per file.)
- AC3 ("Unrelated draft edits are never saved silently.") stands.
