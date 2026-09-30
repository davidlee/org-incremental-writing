# Rigour — reference

Long-form companion to `SKILL.md`. The skill is the compressed, agent-facing
artifact; this document is the reasoning behind it — for humans constructing
other skills, not for consumption by resource-bound agents.

It covers three things:

1. **The premise** — what "edge of capacity" means and why procedure can
   partially substitute for capability.
2. **The behavioural deltas** — for each behaviour that distinguishes a
   frontier model from its predecessors: a mechanistic account of *why* the
   weaker model fails, why the corresponding discipline interrupts that failure,
   and how the discipline itself degrades.
3. **Design principles for skill authors** — the transferable lessons about
   turning behaviour into skill prose, extracted from writing this one.

A note on provenance: this is a distillation from observed behavioural
contrast between model generations, not from measured ablations. Treat the
mechanistic accounts as working hypotheses with good explanatory power, not
established fact. They have earned their place by predicting where procedures
help; they may still be wrong about *why*.

---

## 1. The premise: discipline as a capacity prosthetic

"Edge of capacity" is not a property of the task alone — it is the relation
between task and agent. The same refactor that a frontier model handles as
routine sits at the edge for a mid-tier model, and past the edge for a small
one. The interesting band is the middle: agents **strong enough to execute an
explicit procedure step by step, but not strong enough to generate the
discipline unprompted**. Below that band, the procedure's individual steps
exceed capacity and the skill cannot help. Above it, the behaviours are
internalized and the skill is mostly overhead.

The substitution thesis: most edge-of-capacity failures are not knowledge
gaps. They are **systematic biases of the generation process** — fluency
mistaken for confidence, anchoring on early output, completion pressure,
context decay. Biases operate silently, at moments the agent does not notice.
A procedure works by inserting an explicit checkpoint at exactly the moment
the bias would otherwise operate: the bias needs silence, and the procedure
denies it silence.

This also defines the thesis's limit. Procedure can force a *decision point*
into the open; it cannot supply the *judgement* exercised at that point. A
ledger forces the agent to classify a claim as verified or assumed; it cannot
make the classification correct. Procedure narrows variance and raises the
floor. It does not raise the ceiling.

Corollary for skill design: every step of a discipline must be **individually
within the target agent's capacity**. "Enumerate two hypotheses" works
because generating a second plausible hypothesis is easy once demanded;
what was hard was noticing that only one existed. If a discipline's steps are
themselves edge-of-capacity, the skill has merely relocated the failure.

---

## 2. The behavioural deltas

Ten deltas, mapped to seven disciplines (two pairs merge, one becomes the
calibration dial rather than a discipline):

| Delta | Behaviour | Discipline |
|---|---|---|
| A | Calibration — confidence tracks evidence | Epistemic ledger |
| B | Hypothesis discipline | Differential diagnosis |
| C | Verification-first | Pre-registered verification |
| D | Strategic context construction | Context economy |
| E | Risk-ordered decomposition | Risk-ordered decomposition |
| F | Surprise sensitivity | Differential diagnosis (trigger) + Tripwires |
| G | Metacognitive tripwires | Tripwires |
| H | Effort calibration | The calibration dial (posture-level) |
| I | Boundary honesty / escalation | Epistemic ledger (unknowns register) |
| J | State externalization | State externalization |

Each section below: the behaviour as observed in frontier models; the failure
mechanism in weaker ones; why the procedure interrupts it; how the procedure
itself fails.

### A. Calibration

**Behaviour.** A frontier model's expressed confidence roughly tracks its
evidence. It distinguishes spontaneously between "I read this in the file",
"this follows from what I read", and "I am assuming this" — and its downstream
decisions weight those differently.

**Failure mechanism.** Confidence, in generated text, is a *register* — a
stylistic property of tokens. The training corpus is dominated by expert prose
whose confident register was backed by actual evidence; the register transfers
to the model without the epistemic backing. So a weaker model produces
confident prose whose confidence is uncoupled from grounding, and — worse —
**re-reads its own confident prose as evidence** on later turns. Confabulation
compounds through self-conditioning. The model has no native signal for "this
claim of mine is ungrounded"; fluency and truth feel identical from inside.

**Why the discipline works.** Tagging claims `verified | inferred | assumed`
converts an implicit, continuous, unavailable quantity (calibration) into a
discrete, cheap classification (provenance: did I observe this?). The
classification is vastly easier than calibration itself — it asks about the
*history* of the claim, not its probability. And once tagged, the tag is an
artifact: later reasoning (and the human) can audit it, and rule 2 ("build
nothing irreversible on `assumed`") converts the audit into action.

**How it fails.** Tag inflation: everything becomes `inferred` because
inference feels respectable. The mitigation is the definition — `verified`
means *observed this session*, not "surely true". Second failure: the ledger
becomes ceremony, maintained but never consulted. That is what the anti-
ceremony guardrail exists for: a ledger that never changed a decision is
evidence the posture should be lightened, not performed harder.

### B. Hypothesis discipline

**Behaviour.** Faced with an anomaly, a frontier model holds several live
explanations, seeks the observation that *discriminates* between them, and
updates — including abandoning a favoured hypothesis, including noticing that
the evidence fits none of them.

**Failure mechanism.** Anchoring, with a mechanistic twist: the first
plausible hypothesis, once generated, becomes *context*. All subsequent
reasoning conditions on it. The model then seeks confirming evidence — not
from motivated reasoning in the human sense, but because the hypothesis-in-
context shapes what completions are probable. Probes get chosen to confirm
(cheap, expected to succeed) rather than to discriminate (which requires
representing the alternative). Symptom-patching follows naturally: if the
first hypothesis is assumed, the obvious action is the fix it implies.

**Why the discipline works.** Forced enumeration of ≥2 hypotheses breaks the
conditioning monopoly — the alternative now also exists in context, and the
question "which observation distinguishes these" becomes *askable*. It was not
askable with one hypothesis; there was nothing to distinguish. Predicting each
hypothesis's expected result before observing is a pre-commitment (see C) that
makes the update honest: the observation arrives into a context that already
says what each hypothesis expected of it. And "never fix what you can't
explain" blocks the symptom-patch exit route.

**How it fails.** The strawman second hypothesis — technically enumerated,
never seriously held. Hard to fully prevent with procedure; the partial
mitigation is framing ("what would a colleague suggest?") and the requirement
that the probe *discriminate*, which a strawman survives poorly: if hypothesis
2 is absurd, no probe is needed to kill it, and the procedure visibly reduces
to one hypothesis again — which is itself a detectable state.

### C. Verification-first

**Behaviour.** A frontier model decides what evidence would demonstrate
success — and what would falsify it — *before* acting, then holds itself to
that. It treats "the tests pass" and "the change is correct" as different
claims.

**Failure mechanism.** Two forces. First, **completion pressure**: models are
trained toward helpfulness and task completion; "done" is the attractor state,
and any passing signal near the end of a task gets read as license to declare
it. Second, **outcome seduction**: evidence evaluated *after* the fact is
evaluated by an agent that wants a particular answer. A test written after the
fix inherits the fix's assumptions — it verifies the implementation against
itself. This is the oldest failure in empirical method, and the model
recapitulates it faithfully.

**Why the discipline works.** Pre-registration is the classical remedy, imported
whole: fix the goalposts before the evidence arrives, so the evidence cannot
move them. The falsification framing ("what observation would prove me
wrong?") counteracts pass-seeking — a check chosen for its ability to fail is
informative; a check chosen to pass is not. "Report the evidence, not the
sentiment" targets completion pressure at the reporting boundary: the agent
must state *what was observed*, which is checkable, rather than *that it
succeeded*, which is a mood.

**How it fails.** Pre-registering trivial checks — goalposts fixed, but fixed
somewhere meaningless. The guardrail is the tautology test: *a check that
cannot fail verifies nothing*. Also vulnerable to time pressure: verification
is the step most often silently dropped, which is why the skill demands the
drop be *reported* ("verification was skipped and why") — converting silent
downgrade into visible decision.

### D. Strategic context construction

**Behaviour.** A frontier model reads with a question in hand, knows what
"enough" looks like before starting, stops there, and keeps distilled
conclusions rather than raw material. It treats its own context as a scarce,
decaying resource.

**Failure mechanism.** Reading *feels like progress* — each file ingested is
visible motion — and the cost side is invisible: a model has no felt sense of
context pressure, and middle-of-context degradation is precisely the kind of
failure the degraded system cannot perceive in itself. So greedy reading
dominates: retrieval without a question, producing coverage instead of
answers, until quality quietly decays. Tangent-chasing compounds it — each
source raises questions whose pursuit raises more (the helium-balloon
problem).

**Why the discipline works.** Writing the question and stopping condition *before*
reading converts open-ended ingestion into search with a termination
predicate. The stopping condition does the heavy lifting: it is decided while
the agent is still fresh and neutral, not mid-read when curiosity and
sunk-cost distort the call. Compress-as-you-go exploits the mechanics of
degradation: distilled notes re-enter context at positions that survive, while
raw middle-of-context recall decays; the notes are the part you keep.
Delegation (where the harness allows) keeps bulk out of context entirely —
conclusions travel, file dumps don't.

**How it fails.** Lazily-set stopping conditions cause premature stops — the
procedure is only as good as the up-front predicate, and a weak agent may set
a weak one. Partially self-correcting: a wrong stop surfaces as `assumed`
claims in the ledger (A) or as surprise later (F), both of which re-open the
question. Which is the general pattern: disciplines back-stop each other.

### E. Risk-ordered decomposition

**Behaviour.** A frontier model decomposes work to *retire uncertainty*: it
identifies which decisions are foundational, attacks the riskiest unknown
first with the smallest probe that could kill it, and defers reversible
decisions. Boundaries are drawn so pieces verify independently.

**Failure mechanism.** Easiest-first is a progress-signal maximizer — visible
motion, early wins, everything green until the fatal unknown at the end, where
it is most expensive. Two forces produce it: completion pressure again (each
finished sub-task is a completion reward), and **narrative-order planning** —
models tend to plan in the order the problem statement presents, which is
rarely risk order. Big-bang integration is the same failure at the boundary level:
risk compounds silently in unassembled pieces.

**Why the discipline works.** "Mark which decisions are foundational" forces the
dependency analysis that narrative-order planning skips. "Smallest probe that
could retire it" is information-per-token maximization — a spike or thin
end-to-end path buys certainty precisely where variance is highest.
Explicitly naming easiest-first as the anti-pattern matters more than it
seems: models are better at recognizing a *named* failure mode in their own
behaviour than at deriving it (see §3).

**How it fails.** Everything gets marked foundational, and the ordering
collapses back to arbitrary. The discriminating question is in the skill:
*would the rest of the work be rebuilt around it if it changed?* Most
decisions fail that test honestly applied.

### F. Surprise sensitivity

**Behaviour.** When an observation contradicts its model of the system, a
frontier model *stops*. It treats the anomaly as information — the most
valuable kind, evidence that the map is wrong — and reconciles before
building further.

**Failure mechanism.** Smoothing contradictions into a coherent narrative is,
in a real sense, what language models *do* — the plausibility gradient favours
text in which things make sense. Explaining away an anomaly ("probably a
stale cache", "must be a flake") is locally cheaper than revising the model of
the system, and the revision has no advocate in the moment. Note the
prerequisite failure: an agent that never predicted anything *cannot be
surprised*. Without expectations on record there is no contradiction to
notice — anomalies present as noise.

**Why the discipline works.** Two parts. The tripwire converts a felt anomaly into
a procedural halt — "surprise blocks the next forward step" is mechanical, not
a judgement call. And the *capacity to be surprised* is manufactured upstream
by other disciplines: pre-registered predictions (C) and ledgered expectations (A)
put expectations on record, so contradiction becomes detectable rather than
smoothable. This is the deepest inter-discipline dependency: surprise sensitivity
is not a standalone behaviour but a *product* of prediction discipline.

**How it fails.** Anomalies below the noticing threshold — no procedure fires
on a surprise that never registers. Mitigation is upstream (more prediction →
more detectable surprise), plus honest parking: the skill permits an anomaly
to be explicitly parked with consent, which keeps the reconcile-everything
bar from becoming so expensive the agent quietly abandons the tripwire.

### G. Metacognitive tripwires

**Behaviour.** A frontier model notices *thrash* — repeated failures, circular
edits, drifting scope — and responds by changing **strategy**, not intensity.
It abandons approaches early, on signal, rather than late, on exhaustion.

**Failure mechanism.** Retry escalation: same strategy, more force. The
mechanism is that in-the-moment assessment is performed by the same agent
whose plan is failing, under sunk-cost pressure, with the failed attempts
themselves polluting context ("so close"). Judgement-based stopping rules fail
*precisely when needed*, because the moment of failure is the moment
judgement is most compromised. This is why the skill's tripwires are
mechanical — numbers and observable, not vibes: two failed attempts; third
touch of the same file for the same reason; can't connect current action to
stated goal.

**Why the discipline works.** A mechanical rule set *in advance* is a commitment
device — it was chosen by the agent at its most neutral, and checking it
requires no judgement at the compromised moment, only counting. "The third
attempt must be a different strategy" further blocks the loophole of counting
a trivially-varied retry as new. Framing tripping as *information, not
failure* matters for compliance: an agent that reads the tripwire as an
accusation will rationalize around it.

**How it fails.** Definitional gaming — "this isn't really a second attempt,
it's a refinement". Partially mitigated by the circular-edit rule (file
touches are harder to redefine than "attempts"). Ultimately this discipline has the
weakest enforcement, because it polices the agent's own accounting; the
scope-drift rule ("re-derive the chain from goal to action") is the backstop,
since a thrashing agent usually cannot produce the chain.

### H. Effort calibration

**Behaviour.** A frontier model matches analytical depth to stakes: it will
spend an hour of thinking on an irreversible architectural call and none on a
rename, and it makes that allocation *silently and correctly*.

**Failure mechanism.** Uniform effort. Weaker models apply roughly constant
depth everywhere — gold-plating trivia while under-analysing the decisive
call, because nothing in the generation process prices one decision
differently from another. Skills themselves aggravate this: **a skill that
demands full ceremony unconditionally gets either applied uniformly (cost
explosion) or, eventually, ignored entirely** (compliance collapse). Both
outcomes kill the skill.

**Why it's the dial, not a discipline.** Calibration is a posture-level property —
it governs *how much of the rest to apply*, so it must run before the disciplines
and gate them. The stakes × reversibility 2×2 makes the allocation cheap: two
one-bit judgements the target band can make reliably, versus the continuous
depth-allocation that it can't. Saying the quadrant *out loud* is another
pre-commitment: a declared calibration is auditable and resists silent drift.

**How it fails.** Everything self-assesses as high-stakes (self-importance) or
low-stakes (laziness). The re-evaluation rule ("a task can migrate quadrants
mid-flight") catches the second; the first is bounded by the anti-ceremony
guardrail — over-armed rigour that never changes a decision is defined as
evidence of miscalibration.

### I. Boundary honesty

**Behaviour.** A frontier model distinguishes unknowns it can resolve from
unknowns that are genuinely the human's to decide — preference, priority,
appetite for risk — and surfaces the latter *early*, with options and a
recommendation, rather than guessing silently or asking lazily.

**Failure mechanism.** Silent guessing, from two directions. Completion
pressure again: asking feels like failure to deliver, so the gradient favours
producing *an* answer. And misclassification: a human-decision unknown
mistaken for a research-resolvable one sends the agent on a long, doomed
research detour — no amount of file-reading resolves a preference. The inverse
failure exists too: over-asking, deferring judgement the agent should own,
which trains the human to stop reading the questions.

**Why the discipline works.** The classification step (research-resolvable vs
human-decision) is the decisive move — it forces the question "*could* any
amount of reading settle this?" before either guessing or asking. The
options-plus-recommendation format attacks the asking-aversion economically:
it converts the interruption from a burden (open question, thinking delegated
upward) into a decision (bounded, pre-analysed, cheap to answer), which makes
asking feel — and be — less like failure.

**How it fails.** Boundary disputes: many unknowns are genuinely mixed
(research narrows them, preference settles them). The practical test is
whether two competent engineers with full context would still disagree — if
yes, it's preference, surface it. That test lives in this document rather than
the skill; the skill carries only the classification demand.

### J. State externalization

**Behaviour.** A frontier model works as though its context could vanish at
any moment — decisions, rationale, and open questions land in durable
artifacts as they occur, and a cold-start successor could resume from those
artifacts alone.

**Failure mechanism.** Context *feels* durable from inside; nothing signals
that it is one compaction away from gone. So state accumulates implicitly —
the plan drifts from its written form, decisions live only in conversation,
rationale evaporates. The batch-documentation instinct ("I'll write it up at
the end") fails structurally: the end is where context pressure peaks and
where completion pressure is strongest — documentation is the first thing
dropped. And rationale-free records ("decided X") are almost as bad as none:
the *why* is what prevents expensive re-litigation by whoever resumes,
including the same agent post-compaction.

**Why the discipline works.** Write-through (update the artifact when the state
changes) removes the batch step entirely — there is no documentation phase to
drop. The cold-start test ("could a fresh agent resume from artifacts
alone?") is a checkable predicate for a property — sufficiency — that is
otherwise hard to assess, and asking it at natural pauses points directly at
the next gap to close.

**How it fails.** Journaling ceremony — artifacts maintained but not load-
bearing, written to satisfy the procedure rather than to be read. The
*why*-requirement is the main defence (rationale is hard to fake and is
exactly the high-value content); the anti-ceremony guardrail is the general
one.

---

## 3. Design principles for skill authors

Extracted from constructing `/rigour`; intended to transfer to other skills.

**Route on symptoms, not stages.** Stage-keyed guidance ("during design, do
X") requires the agent to correctly locate itself in a lifecycle — itself an
edge-of-capacity judgement, and wrong exactly when it matters. Symptom-keyed
guidance ("behaviour contradicts your model → differential diagnosis")
requires only *noticing*, which is cheaper and fires at the moment of need.
Symptoms are also stage-portable: the same routing works in design, debugging,
or review.

**Every procedure needs an exit condition.** An open loop gets abandoned
silently, and the abandonment is invisible — the agent just stops doing it.
An explicit exit ("every consequential claim is verified/inferred, or its
assumed status is declared") makes completion checkable and makes *non*-
completion a visible state that must be either finished or explicitly waived.

**Mechanical beats judgemental at the moment of failure.** Any rule that
requires judgement at the moment the agent is compromised — mid-thrash, under
sunk cost, at completion pressure — will be rationalized around. Rules that
bind must be checkable without judgement: counts, file-touch tallies,
observable predicates. Spend the judgement budget at neutral moments (setting
stopping conditions, pre-registering checks, declaring the quadrant) and let
the compromised moments run on rails.

**Pre-commitment is the master pattern.** It recurs in nearly every discipline:
predict before observing, define the check before acting, set stopping
conditions before reading, fix tripwire counts before starting, declare the
quadrant out loud. The common mechanism: decisions made early, by the agent
at its most neutral, then *externalized* so the compromised later self cannot
silently revise them. "Say it out loud" is not ceremony — an unstated
commitment is not a commitment.

**Name the anti-pattern.** Models recognize a *named* failure mode in their
own behaviour far more reliably than they derive it from principles.
"Easiest-first is the anti-pattern", "fluency is not evidence", "a test that
cannot fail verifies nothing" — each is a recognition handle. One crisp
negative sentence often outperforms a paragraph of positive instruction.

**Build in a calibration valve.** A skill that demands its full ceremony
unconditionally dies one of two deaths: uniform over-application (cost
explosion, user turns it off) or quiet abandonment (agent learns to ignore
it). The valve — a cheap up-front dial plus an anti-ceremony guardrail that
*defines* unproductive ceremony as miscalibration — is what lets a skill stay
armed for years. This may be the least obvious and most important principle.

**Steps must be individually sub-capacity.** The substitution thesis's hard
limit (§1): a procedure helps only if each step is easier than the judgement
it replaces. "Enumerate two hypotheses" passes (generating a second is easy
once demanded; *noticing you only had one* was the hard part). "Correctly
weight the evidence" fails (that *is* the hard part, restated). When drafting
a step, ask: is this a checkpoint, or is it the original problem wearing a
procedure costume?

**Let disciplines compound, but degrade gracefully.** The deepest structure in
`/rigour` is that disciplines manufacture each other's preconditions: surprise
sensitivity (F) only exists downstream of prediction discipline (C) and a
ledger (A); a bad stopping condition (D) is caught later as an assumed claim
(A) or a surprise (F). Design for that reinforcement — but ensure each discipline
still pays for itself alone, because partial adoption is the normal case.

**Write for the weakest intended reader.** Short imperative steps. Tables
over prose where structure is the content. One idea per sentence. Concrete
anti-patterns over abstract principles. The stronger reader loses nothing;
the weaker reader — the one the skill exists for — keeps the thread. Note the
tension with register: compression must not become telegraphic ambiguity.

**Know what doesn't transfer.** Procedure cannot convey taste: which
hypothesis is *actually* plausible, which claim *actually* matters,
when a rule's exception genuinely applies. A skill narrows variance and
raises the floor; the ceiling stays where the model put it. Budget your
skill-writing effort accordingly: target the failures that are *biases*
(where checkpoints work) rather than the failures that are *capability gaps*
(where they don't).

---

## 4. Limits and open questions

**The prosthetic tax.** For agents above the target band the posture is
mostly overhead — the behaviours are internalized and the ceremony competes
with them for tokens. The calibration dial partially addresses this (a strong
agent should self-assess into lighter quadrants), but an explicit "you may
already be above this" release valve was considered and rejected as too easy
a rationalization for exactly the agents that need the skill. Open question
whether that was right.

**Compliance decay over long sessions.** Postures erode; an agent that armed
the ledger at hour one may have silently dropped it by hour three. The skill's
current answer is the no-silent-downgrade guardrail plus quadrant
re-evaluation, both of which rely on the agent noticing. A harness-level
answer (periodic posture re-injection) would be stronger but is out of scope
for a harness-agnostic skill.

**Self-accounting is the weak joint.** Tripwires police the agent's own
counting; the ledger polices the agent's own honesty about provenance. An
agent motivated (by completion pressure) to game its accounting can. The
disciplines are designed so gaming leaves visible residue — a strawman hypothesis
is detectable, a tautological check is nameable — but detection assumes
someone looks. Adversarial review of the *process artifacts* (not just the
output) is the natural complement.

**Unmeasured.** No ablation data: which disciplines carry the most value, whether
the routing table actually gets used or agents read top-to-bottom, whether
the calibration dial is honoured under pressure. The skill's structure
(discrete disciplines, explicit exits) is deliberately amenable to being
instrumented later — per-discipline adoption and outcomes are observable in
transcripts if anyone cares to measure.
