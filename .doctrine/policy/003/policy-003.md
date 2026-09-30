# POL-003: Working software, verified by human trial

## Statement

- Every slice delivers a runnable increment of user-visible value.
- Every slice's plan includes at least one human-verified (VH) criterion:
  a short trial script the user runs in their own Emacs.
- A slice does not close until the user has run the trial and reported
  the result. Automated tests are necessary but not sufficient.
- Infrastructure, abstraction and governance are built only as far as the
  current increment needs ("just in time").

## Rationale

Value is proven in use: whether a queue interaction feels right cannot be
settled by tests. Trialling after every slice catches wrong assumptions
while they are cheap, and it keeps work pointed at something the user
actually uses rather than at scaffolding.

## Scope

All slices. Pure-maintenance chores with no user-visible behaviour may
state that no trial applies, with a reason, in their plan.

## Verification

- The plan must contain a VH criterion.
- The close step requires the recorded outcome of the user's trial.

## References

- PRD-001 § 5.
- RFC-001 slice sequence and governance candidate P3.
