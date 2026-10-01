# CHR-001: Adopt a curated mutation-testing recipe (just mutate)

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

From RV-002 / STD-001 item 3. Turn the RV-002 mutation harness
(`.doctrine/slice/001/research/raw/rv-002/mutation/`; mutant lists in
`rerun/m-head.json`, `m-new.json`) into a `just mutate` recipe: a curated,
per-layer list of mutants anchored on code (not line numbers), each run
against the full suite. It reports killed/survived, and survivors need a
recorded justification. All 79 mutants ran in about 9 s, cheap enough for
phase end. Record the mutant set with the results, so a kill rate can be
reproduced (RV-002 friction: the review's 57/71 couldn't be rebuilt).
