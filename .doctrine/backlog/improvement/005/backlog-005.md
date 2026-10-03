# IMP-005: Uniform title rendering in mode line and messages; compact ID forms if IDs stay user-visible

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Raised during SL-003 design (2026-10-03, inq-5 / DEC-017: the view
renders titles with `org-link-display-format`).

1. The mode line (`IW[Queue: Title]`) and command messages show the raw
   title, so a heading with a link shows link syntax there but a clean
   description in the queue view. Make them uniform: one title-rendering
   function used by view, mode line and messages (POL-002).
2. User: "if IDs remain part of the display surface / UX in any meaningful
   way, we ought to consider much more compact ID forms than GUIDs (e.g.
   nanoids)." IDs appear today in refusals, e.g. "ID %s is duplicated"
   (`org-iw--refuse-absent`) and discovery refusals. Org generates IDs per
   `org-id-method` (uuid by default; `ts` and `org` are shorter), so the
   options include: avoid showing IDs at all (prefer title + file), show an
   abbreviated ID, or recommend/offer a compact `org-id-method`. Generating
   non-Org IDs would interact with QUE-002 (identity source).
3. Titles keep Org's double space where a mid-heading statistics cookie
   is stripped (`* Plan [1/3] Site` → "Plan  Site"), as outlines did
   until RV-006 F-4 (cbb493e) normalised them in discovery with
   `string-clean-whitespace`. The title is read by
   `org-iw-discovery--title`; fix it there, in discovery, the one Org
   reader. User (2026-10-03): fix at some point, timing open.
