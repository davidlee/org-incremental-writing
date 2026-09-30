---
name: rigour
description: Use when operating at the edge of your capacity — high complexity, deep uncertainty, unfamiliar territory, expensive context — and being confidently wrong would be costly. A conduct posture layered onto whatever skill governs the stage; it changes how you work, not which work you do.
---

# Rigour

A conduct posture for work at the edge of capacity: problems whose complexity,
uncertainty, or context cost exceeds what fluent improvisation can carry.
Layer it on the governing stage skill (design, execute, audit, …) the way
pairing or walkthrough is layered — it does not replace routing, and it is not
a stage.

At the edge, specific failure modes dominate: confabulated confidence,
anchoring on the first hypothesis, greedy reading, success declared without
evidence, retrying harder instead of differently, and state lost to context
pressure. Each discipline below substitutes an explicit procedure for the judgement
that would otherwise have to be flawless. Discipline is cheaper than capacity;
buy correctness with process.

## Calibrate before engaging

Rigour costs tokens and time. Set the dial by **stakes × reversibility**:

|  | Reversible | Hard to reverse |
|---|---|---|
| **Low stakes** | no posture — just work | pre-registered verification only |
| **High stakes** | ledger + verification | full posture, all disciplines armed |

Say out loud which quadrant the task is in and which disciplines you are arming.
Re-evaluate when scope shifts — a task can migrate quadrants mid-flight.

## Routing: symptom → discipline

Route on the *symptom you notice*, not the lifecycle stage:

| Symptom | Discipline |
|---|---|
| Confident conclusions resting on thin evidence | Epistemic ledger |
| Behaviour contradicts your model of the system | Differential diagnosis |
| About to commit a hard-to-reverse change | Pre-registered verification + ledger audit |
| Problem won't fit in context; reading feels bottomless | Context economy |
| Too big / too tangled to start | Risk-ordered decomposition |
| Second or third failed attempt at the same thing | Tripwires |
| An unknown you cannot resolve yourself | Epistemic ledger → escalate |
| Long task; context loss or handover plausible | State externalization |

Symptoms compound; arm every discipline that matches. When none match but the work
still feels beyond you, that itself is a tripwire — stop and reassess.

## The disciplines

### Epistemic ledger

Track what you actually know, separately from what you believe.

1. Tag every consequential claim: **verified** (you observed it), **inferred**
   (it follows from verified claims), or **assumed** (you need it to be true).
2. Build nothing irreversible on an `assumed` claim. Upgrade it — verify or
   derive it — or surface it before proceeding.
3. Keep an explicit register of unknowns, classified: *resolvable by research*
   (go resolve, within the context budget) vs *requires a human decision*
   (surface early, with options and a recommendation — never guess silently).
4. Fluency is not evidence. If a paragraph reads confidently, audit which of
   its claims are actually `verified`.

Exit: every claim the conclusion rests on is `verified` or `inferred`, or its
`assumed` status is declared to the user.

### Differential diagnosis

For faults, anomalies, and any moment the system contradicts your model.

1. Halt forward progress. An anomaly is evidence your model is wrong; work
   built on a wrong model is waste. Do not rationalize it away.
2. Enumerate **at least two** live hypotheses. One hypothesis is anchoring.
3. Choose the *cheapest observation that discriminates between them* — not
   the easiest fix to try. Predict each hypothesis's expected result first.
4. Observe, update, prune, repeat. Add hypotheses when evidence fits none.
5. Never fix what you cannot yet explain. A patch that works for unknown
   reasons is an `assumed` claim in the ledger.

Exit: one hypothesis explains all observations, including the original
surprise — or the anomaly is explicitly parked with the user's consent.

### Pre-registered verification

Decide what proof looks like *before* acting, so the outcome cannot seduce you.

1. Before a change: write down what observation would demonstrate success
   *and* what would falsify it.
2. Prefer checks that would fail loudly if you are wrong — a test that cannot
   fail verifies nothing.
3. After the change, run the pre-registered check. "It ran" / "it compiles" /
   "it passes what already passed" is not the check.
4. Report the evidence, not the sentiment: state what was observed, or that
   verification was skipped and why. Never let completion pressure downgrade
   the check.

Exit: the pre-registered observation was made and matched, or the mismatch is
reported as a finding rather than smoothed over.

### Context economy

Context is the scarcest budget; spend it with a plan and stop conditions.

1. Before reading anything, write the question you are trying to answer and
   the concrete stopping condition — what suffices, even if incomplete.
2. Read goal-first: skim structure, then descend only into what bears on the
   question. Note tangents to a list instead of chasing them.
3. Compress as you go: after each source, distil what it contributed to one
   or two lines of durable notes. The notes are what you keep; raw recall of
   middle-of-context detail will decay.
4. Delegate bulk reading where your harness allows — keep conclusions, not
   file dumps, in your own context.
5. When context pressure rises, externalize (see below) before quality
   degrades, not after.

Exit: the pre-stated question is answered to the stopping condition, and the
answer survives in notes rather than in unaided recall.

### Risk-ordered decomposition

Sequence work to retire uncertainty, not to feel progress.

1. List the decisions and unknowns; mark which are *foundational* — those the
   rest of the work would be rebuilt around if they changed.
2. Attack the riskiest foundational unknown first, with the smallest probe
   that could retire it (a spike, a stub, a thin end-to-end path).
3. Defer reversible decisions; keep options open where deferral is cheap.
4. Divide the work so each piece is *independently verifiable* — integration
   risk compounds silently in big-bang assembly.
5. Easiest-first is the anti-pattern: it manufactures visible progress while
   the fatal unknown waits at the end, when it is most expensive.

Exit: remaining work is low-variance — no unknown left that could invalidate
what has been built.

### Tripwires

Mechanical stop conditions, set in advance — because in the moment, you will
rationalize continuing.

- **Two failed attempts** at the same fix → stop. The third attempt must be a
  different *strategy*, not more intensity; usually it should be diagnosis
  (see differential diagnosis) or escalation.
- **Circular edits** — touching the same file the third time for the same
  reason → stop, restate the actual problem from scratch.
- **Scope drift** — current action hard to connect to the stated goal → stop,
  re-derive the chain from goal to action; prune or re-plan.
- **Surprise** — any observation contradicting the ledger → differential
  diagnosis, before the next forward step.
- **Sunk cost** — "too far in to change approach" is the tripwire itself, not
  a reason to continue.

Tripping one is information, not failure. The formidable behaviour is
changing strategy *early*, on a signal, rather than late, on exhaustion.

### State externalization

Assume your context can be lost at any moment; work so that it barely matters.

1. Keep the durable state — plan, decisions with rationale, ledger, open
   questions, next step — in artifacts, not in your head. Write through:
   update the artifact when the state changes, not in a batch at the end.
2. Record *why* alongside *what*: a decision without rationale gets expensively
   re-litigated by whoever resumes — including future you.
3. At any natural pause, ask: could a fresh agent resume from the artifacts
   alone? If not, the gap is the next thing to write down.
4. Route durable knowledge to wherever it outlives the task (project memory,
   design docs, notes) rather than leaving it in conversation.

Exit: a cold-start reader could continue the work from artifacts alone.

## Guardrails

- Do not perform rigour. The ledger, hypotheses, and checks exist to change
  your actions; ceremony that never alters a decision is waste — drop to a
  lighter quadrant instead.
- Do not let the posture replace the stage skill's own process; it augments.
- Do not silently downgrade mid-task. If you abandon a discipline under time or
  context pressure, say so.
- Uncertainty is reported, never laundered: an `assumed` claim stays visibly
  assumed all the way into the final summary.

## Outcomes

- Conclusions trace to verified observations; assumptions are visible, not
  embedded in fluent prose.
- Faults get explained, not patched around.
- The riskiest unknowns die first, while changing course is still cheap.
- Failure triggers strategy change early, on a signal.
- Context loss is survivable at every point; a successor can resume from
  artifacts alone.
