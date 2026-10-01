`doctrine slice verify-vt` matches each VT keyword as a literal anywhere in
the committed `test_file`. Consequences seen in SL-001 (RV-002 F-20):
- moving a helper to another file silently breaks a row (workers then add
  "keyword bait" comments/docstrings to restore it);
- a row can pass before its test exists (keyword in an unrelated test);
- a `test_file` pointing at a helper library proves only the helper exists;
- uncommitted work isn't seen, so a worker can't self-check before commit;
- user-facing message text as a keyword couples plan.toml to UX wording.
When authoring VTs: key on `ert-deftest` names (or code symbols), point
`test_file` at a file of tests, never use message text.

SL-002 (RV-004 F-1): rows keyed on message text pass at their own phase and
break silently when a later phase changes the wording, as planned. Re-run
`verify-vt <slice>` over the whole slice at every phase end and at audit, not
just the current phase's rows. Repair by the append rule: add a re-keyed row
(new VT id) and set the old row's `waived = true, waived_reason = "…"`;
verify-vt prints the reason (`~ WAIVED VT-n — <reason>`). `waived_reason`
isn't in the plan.toml template; it was found in the binary (doctrine 0.46.5).
