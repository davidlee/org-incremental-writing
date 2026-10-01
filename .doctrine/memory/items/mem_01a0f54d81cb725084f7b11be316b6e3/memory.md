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
