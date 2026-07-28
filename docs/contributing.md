# Contributing

Contributions are welcome under the project's
[MIT License](../LICENSE). The current `0.9.0-beta` branch is under
[Feature Freeze](feature-freeze.md), so contribution scope is intentionally
narrow.

## Before opening a change

- Search existing issues and the [Beta Issue Ledger](beta-issues.md).
- Use [private vulnerability reporting](security-policy.md) for security
  findings; do not publish exploit details in a normal issue.
- Confirm the proposal fits the active freeze. New commands, settings, themes,
  background behavior, supported shells, install locations, or broad support
  claims are deferred.
- For device-specific claims, provide real-device evidence. A portable fixture
  alone is not sufficient.

## Change rules

- Keep Bash syntax portable across the verified development and Termux paths.
- Preserve the strict settings, theme, filesystem, ownership, and output
  boundaries.
- Do not use `eval` or source user settings/theme data.
- Keep renderer state free of ANSI bytes; add styling only at output.
- Preserve render-once behavior and bounded optional probes.
- Add focused regression coverage for every behavior or documentation change.
- Assign each new `tests/test_*.sh` file exactly once in
  `scripts/quality-check.sh`.
- Update public documentation when a user-visible contract changes.

## Verify locally

Run the canonical gate from the repository root:

```bash
bash scripts/quality-check.sh
```

Also run the focused test directly while iterating. For documentation changes:

```bash
bash tests/test_documentation.sh
```

Package-affecting changes must pass the extracted-artifact lifecycle:

```bash
bash tests/test_release_artifact.sh
```

Portable success does not establish device compatibility or reference-device
performance. See [Development](development.md) for the evidence split.

## Commit scope

Keep commits focused and reviewable. Do not combine documentation or a bounded
fix with unrelated refactors. Preserve executable modes for scripts/tests and
mode `0644` for Markdown and SVG assets.

When describing a change, include:

- the problem and intended boundary;
- affected commands, paths, and versions;
- tests run and their result;
- device evidence, if the claim is device-specific;
- security or privacy implications;
- any known limitation left in place.
