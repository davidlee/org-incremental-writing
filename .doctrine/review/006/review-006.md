# Review RV-006 — code-review of SL-003

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

Scope: SL-003 PHASE-01..03, diff e7213f2..afec99d (source and tests).
Roster per STD-003: modelling/architecture reviewer (opus), test reviewer
(opus, mutation pass), verifier (sonnet). Reviewers are read-only; the
seat writes the ledger.

Lines of attack:
- Write path (ADR-002, I11): delete-rank removes exactly one line; preflight
  shared, not copied (POL-002); rollback restores text and modified flag;
  read-only and indirect buffers; the drawer-survives invariant check.
- Core (I10', ADR-004): beside/step pure; index counted without TARGET;
  clamp; property test actually discriminates (checker self-test).
- Discovery: outline read without extra I/O; the double-space cookie
  artefact (PHASE-01 finding) and what renders it later.
- Command layer (POL-002, I14): one owner each for lookup by ID, queue
  prompt, no-room and absence texts; place called only by Add and --move;
  behaviour preserved for Add/Continue/visit-next; no helper ahead of its
  caller; orchestrator-approved org-iw--heading-or-refuse (deviation D1).
- Tests (STD-001/002): refusals killed; literals pinned; no theatre;
  VT keywords not message text.


## Synthesis

**Overall:** acceptable.

**Synopsis.** PHASE-01..03 follow the locked design closely. The core
helpers are pure and covered by a property test whose checker
demonstrably discriminates. delete-rank reuses the one preflight and
apply; I11 (exactly one line deleted, drawer kept) and rollback were
proved by probe on Emacs 30 and 31. PHASE-03 kept Add, Continue and
visit-next behaviour, gave each concept one owner (lookup by ID, queue
prompt, no-room and absence texts), and added no helper ahead of its
caller. Deviation D1 (org-iw--heading-or-refuse) is sound: it keeps
Add's temporary document refusal out of the shared target helper.

Standing risks are small and local: a read-only indirect buffer reaches
delete-rank as a raw error (F-1, unreachable from commands today); a
few test oracles are blind to context (F-6, F-7, F-8 — F-8 matters
before PHASE-04, whose must-match prompt rests on the recorder). F-3 is
genuine drift between ADR-003 and design § 5.2 and needs a ruling.

Advisory, not raised: three VT keywords (PHASE-01 VT-3, PHASE-02 VT-1,
PHASE-03 VT-2) pre-existed in their files; each row also carries new,
specific keywords, so the gate still has teeth. Prefer only-new
keywords in future rows.

**Haiku**

    One line leaves the drawer;
    the rest hold still, byte for byte —
    mutants fail to bite.
