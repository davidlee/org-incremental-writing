---
name: consult
description: Use the moment you hit an unanticipated obstacle, a decision with competing tradeoffs, or emergent complexity mid-task — before adapting planned scope, adding a dependency, taking a shortcut, or making any impactful concession on your own.
---

# Consult

The user has strong feelings about architecture, plan adherence, and especially
about agents making impactful decisions or concessions without consultation.

DO NOT make them alone.

If you encounter an unanticipated obstacle, YOU MUST consider stopping to
discuss it. If the obstacle:

- requires adaptations that could alter planned functionality
- presents multiple solutions with different tradeoffs
- requires substantial research, debugging, or diverts you from the task
- suggests introducing new imports or coupling vectors
- risks policy violations or doctrinal ambiguity (i.e. heresy — see `/canon`)
- tempts a shortcut or omission

YOU MUST STOP IMMEDIATELY.

Present the situation with context. Summarise:

- the relevant task code, plan, `design.md`, or governing canon
- what you are trying to do
- the nature of the obstacle
- relevant discoveries
- options and/or hypotheses
- any obvious tradeoffs

Then ask for guidance before proceeding.

If the obstacle is really a piece of **latent work** to defer rather than a
decision needing the user now — a follow-up, a newly-spotted risk, a chore — then
**capture** it with `backlog new` so it is not lost to the conversation, and say
so. Is it work, knowledge, or a decision? See the boundary in
`lib:reference/using-doctrine.md`.

Capture the consult's outcome via `/knowledge`: a resolved tradeoff → DEC; one
still open → QUE, with the blocked work gating itself (`doctrine needs <work> QUE-n`).
