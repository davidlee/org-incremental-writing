From SL-001 (PHASE-02..08 and the RV-002 remediation), 2026-10-01:
- `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` must be set when Claude Code
  is launched; a `!` export in-session doesn't reach the harness. Check
  with `printenv` before chartering.
- With background tasks off, spawns run in the foreground; `TaskStop` on
  a finished child returns "No task found". Reaping is a no-op, not an
  error.
- Demand an explicit model plus a real reason for EVERY planner and
  worker in the charter. Orchestrator 2 left planners on "the default"
  until told.
- Charters that worked carried:
  - the gate command with `</dev/null`;
  - the commit-message trailer;
  - "design is locked; escalate gaps in the hand-back";
  - "any public API change is an escalation";
  - the prior orchestrator's rulings and gotchas;
  - "verify the gate yourself";
  - "seat is the sole ledger writer" (for review work).
- Orchestrators escalated well through their hand-backs: append-rank
  signature, Add in a non-Org buffer. Bring these to the user rather than
  ruling at the seat when they touch a locked design.
- Test-first slipped in some worker phases (code before tests, defended
  by after-the-fact mutation). Say "show red before code" explicitly.
- A single worker spawned directly (no orchestrator) suits a one-finding
  fix with the rule already decided; the seat then gates and commits.
