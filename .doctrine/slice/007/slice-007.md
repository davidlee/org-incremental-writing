# Docs and acceptance walkthrough

## Context

RFC-001 slice 7. The PRD-001 § 5 acceptance gate.

## Scope & Objectives

- Docs are split: `README.md` is the front page (what it is, why,
  install via `use-package :vc`, a first round); `doc/manual.md` is the
  reference. Bring both current with the finished feature set, and
  check the PRD-001 § 5 walkthrough is followable from them: install,
  configuration (sources, queues, vocabulary), commands, metadata
  format, save and redistribution behaviour.
- Disposable Git-backed fixture corpus and a walkthrough script.
- The user runs the full PRD-001 § 5 walkthrough.

## Non-Goals

Package-archive publication.

## Summary

Affected surface: `README.md`, `doc/manual.md`, fixtures, walkthrough script.

**Closure:** walkthrough passed by the user (VH).

## Follow-Ups
