`doctrine slice conformance <id>` reads the recorded source deltas. They
can miss a path that the slice edited: SL-003's registry missed
`test/org-iw-test-helpers.el`, which was edited in a phase commit and in
a review-fix commit. The default run reported no code undeclared.

At audit:
- also run `doctrine slice conformance <id> --against <base>..HEAD`,
  where `<base>` is the commit before PHASE-01 (for SL-003, the commit
  that materialised the phases);
- ignore the `.doctrine/` paths it lists, which are metadata;
- treat any remaining undeclared path as a finding, fixed with
  `doctrine slice selector add` plus a design § 10 row (RV-011 F-1).
