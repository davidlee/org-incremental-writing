# POL-001 gate for org-iw (design § 9; justfile replaces the Makefile, see
# SL-001 plan.md). Lint runs on `emacs` (31) only: package-lint, relint and
# undercover are not in the Emacs 30 build. Tests run on both.

set shell := ["bash", "-euo", "pipefail", "-c"]

emacs := env("EMACS", "emacs")
emacs30 := env("EMACS30", "emacs-30")

sources := "org-iw*.el"
elisp := "org-iw*.el test/*.el tools/*.el"

# List recipes.
default:
    @just --list

# Byte-compile each file in its own Emacs, warnings as errors; .elc go to a temp dir.
compile:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    out=$(mktemp -d)
    trap 'rm -rf "$out"' EXIT
    for f in {{elisp}}; do
      {{emacs}} -Q --batch -L . -L test \
        --eval "(progn (require 'bytecomp) \
                  (setq byte-compile-error-on-warn t \
                        byte-compile-dest-file-function \
                        (lambda (f) (expand-file-name (concat (file-name-nondirectory f) \"c\") \"$out\"))))" \
        -f batch-byte-compile "$f"
    done

# Checkdoc every file; fails on any diagnostic.
checkdoc:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    {{emacs}} -Q --batch -l tools/checkdoc-batch.el -f org-iw-checkdoc-batch {{elisp}}

# Package-lint the package sources, org-iw.el as main file.
package-lint:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    {{emacs}} -Q --batch \
      --eval "(progn (require 'compile) (require 'package-lint) \
                (setq package-lint-main-file \"org-iw.el\"))" \
      -f package-lint-batch-and-exit {{sources}}

# Lint regexps in every file.
relint:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    {{emacs}} -Q --batch -l relint -f relint-batch {{elisp}}

# The full lint gate.
lint: compile checkdoc package-lint relint

# Run the ERT suite from source with BIN (default: emacs).
test bin=emacs:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    loads=()
    for f in test/*-test.el; do loads+=(-l "$f"); done
    {{bin}} -Q --batch -L . -L test --eval "(setq load-prefer-newer t)" \
      "${loads[@]}" -f ert-run-tests-batch-and-exit

# Run the suite on Emacs 31 and Emacs 30.
test-all: (test emacs) (test emacs30)

# Per-commit check (`doctrine check commit`).
check: lint test

# End-of-phase gate (`doctrine check gate`).
gate: lint test-all

# Report test coverage of the sources (does not gate).
coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    loads=()
    for f in test/*-test.el; do loads+=(-l "$f"); done
    {{emacs}} -Q --batch -L . -L test \
      --eval "(progn (require 'undercover) (setq undercover-force-coverage t) \
                (undercover \"{{sources}}\" (:report-format 'text) (:send-report nil)))" \
      "${loads[@]}" -f ert-run-tests-batch-and-exit

# Remove stray .elc files from the tree.
clean:
    find . -name '*.elc' -not -path './.git/*' -delete
