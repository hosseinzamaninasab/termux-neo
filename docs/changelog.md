# Changelog

This changelog records verified project checkpoints. Stable `v1.0.0` remains
unreleased.

## 1.0.0-rc.1 — 2026-07-29

- Published the complete public documentation set for the frozen
  `0.9.0-beta` product.
- Added renderer-derived `neo` and `matrix` SVG captures with deterministic
  transcript verification.
- Declared the project license as MIT by explicit owner choice.
- Expanded the canonical quality gate from 24 to 25 test files with a
  documentation and link-integrity regression.
- Made `VERSION` the explicit release-identity source for CLI output, package
  names, the prospective tag, and verified release notes.
- Added a reviewed package allowlist, versioned release-note output, a checksum
  covering both published files, and two-clean-checkout reproducibility gates.
- Expanded the canonical quality gate from 25 to 26 test files with a focused
  release-discipline regression.
- Promoted the synchronized release identity to `1.0.0-rc.1` only after the
  full package, lifecycle, defect, compatibility, and reference-device gates.
- Reserved `v1.0.0` for the stable-release task.
- No runtime, CLI surface, settings, theme, lifecycle, or support behavior
  changed; only the synchronized release identity moved to the candidate.

## 0.9.0-beta — 2026-07-28

- Completed the isolated ten-scenario public-beta lifecycle and environment
  matrix.
- Recorded one physical Samsung `SM-N920C` / Android `11` environment with
  portrait/landscape widths `56` and `94`.
- Verified the external checksum, internal manifest, extracted smoke,
  packaged repeated-render stability, install, update, and both uninstall
  modes.
- Recorded zero open critical security defects and zero open release-blocking
  defects.
- Activated Feature Freeze for the path to `v1.0.0`.

## Earlier verified foundations

- Added a responsive Dashboard, Status, and Prompt renderer with a shared
  display-user boundary.
- Added schema-v1 settings, strict theme parsing, `neo` and `matrix` themes,
  stable CLI dispatch, diagnostics, and optional Bash startup integration.
- Added transactional install, update/migration, and uninstall workflows.
- Added reproducible Git-independent release artifacts, compatibility
  fixtures, CI/quality automation, security/failure-safety review, and measured
  performance/stability gates.

Detailed checkpoint evidence remains in the project history and the public
reference documents linked from [README](../README.md).
