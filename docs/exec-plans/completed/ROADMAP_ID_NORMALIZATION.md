# Execution Plan — Canonical Roadmap Identifier Normalization

**Status:** Complete
**Owner:** Codex/maintainer
**Milestone:** Governance maintenance outside executable milestone work
**Started:** 2026-08-08
**Last updated:** 2026-08-08

## Goal

Replace the parallel Stage-N roadmap identifiers with the single canonical `M0`–`M8` milestone hierarchy while preserving roadmap order, scope, acceptance criteria, and progress.

## In scope

- Authoritative roadmap headings and substep identifiers.
- Mirrored README, status, priority, governance, index, template, playbook, and manifest references.
- Playbook and completed-plan paths that encode the retired identifier system.

## Out of scope

- Any implementation or activation of M1 work.
- Changes to roadmap scope, sequencing, estimates, acceptance criteria, or completion status.

## Validation

- [x] No competing `Stage N`, `STAGE_N`, or unprefixed executable substep identifiers remain in current roadmap material.
- [x] Markdown links and repository manifest entries resolve.
- [x] JSON/YAML and secret checks pass.
- [x] Diff contains identifier normalization only.
- [x] Commit scope is ready for atomic persistence to `origin/main`.

## Completion summary

Canonical milestone identifiers now run from M0 through M8, with every executable roadmap item using an `M<n>.<substep>` identifier. Mirrored status material, governance, templates, playbooks, paths, and manifest metadata use the same system. Roadmap scope, order, estimates, acceptance criteria, and completion state are unchanged. M1 remains unauthorized and inactive.
