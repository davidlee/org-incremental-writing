# IMP-007: Prompt recorder should fail on unconsumed answers

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found by RV-009's test reviewer (SL-003 PHASE-07); predates the phase
(the macro came in 7fe8fc2, SL-002), so out of RV-009's scope.

`org-iw-cmd-test--with-prompt` in `test/org-iw-test.el` fails when it runs
out of answers, but not when answers are left over after BODY. A test that
wraps a command in `(with-prompt :yes ...)` and doesn't assert `:prompt`
would pass even if the command never prompted. No vacuous pass exists
today (`view-remove` asserts the prompt).

Fix: after BODY, `(when answers (ert-fail (list "Unanswered" answers)))`,
plus a self-test case. The reviewer checked the suite stays 326/326.
