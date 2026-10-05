- `review_policy` values over 16 bytes are refused ("payload label term is
  N bytes, over the 16-byte admission bound"): `adversarial-then-human`,
  `human-then-adversarial`. Run the adversarial pass on the RV anyway and
  keep human-only (SL-002, 2026-10-01).
- Human section review is `declare` entries `{subject: att-…, attests:
  sec-…, reviewer: human}`, not a `checkpoint_act` `section-reviewed`
  (refused: "binds to per-section coverage and the act carries none").
- `review-disposed: conducted` needs every major/blocker finding to carry
  a route. For a verified finding without one: raiser `review reopen`,
  responder `review dispose --route …`, raiser `review verify`, then
  `review conclude` again and re-record the disposition.
- Each inquiry needs its own `cp-` disposition. A second inquiry sharing a
  record uses `dispose: {form: adopt, record: DEC-…}` after the first one
  creates it.

- Amending a locked design (SL-003, 2026-10-05): regress FIRST, with
  design.md untouched. `adopt` refuses on a locked run, and the regress
  refuses once design.md differs from the run. Order: `apply`
  `{"stage":{"to":"reviewing",...}}` → edit design.md → `design adopt`
  → re-`declare` the invalidated sections (human) → conclude the
  auto-opened design RV → `checkpoint_act` review-disposed
  (`disposition: {conducted: {review: RV-…}}`) → design-accepted → stage
  locked. Each apply needs the current `known_revision`; every act needs
  `acceptance.basis` citing the user's reply.
- After a re-lock, status shows "1 change since baseline" and the RV
  "STALE": that is the lock act itself, not a content drift.
