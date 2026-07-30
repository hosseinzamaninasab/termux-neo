# Feature Freeze

Status:

```text
COMPLETE — 1.0.0
```

The stable-release branch completed its freeze at the verified `v1.0.0`
checkpoint. Product scope, CLI surface, configuration schema, themes, render
geometry, and lifecycle ownership did not expand after the Task 31 candidate.

## Changes allowed during the freeze

Only these classes may enter:

- a fix for a release-blocking defect;
- a security fix;
- a compatibility fix backed by repeatable evidence;
- a documentation correction that matches existing behavior.

Every allowed change requires a recorded defect or documentation mismatch,
focused regression coverage, the full quality pipeline, release-artifact smoke,
and an updated Project Master checkpoint.

## Changes deferred

New commands, settings keys, themes, background behavior, telemetry, supported
shells, installation locations, and unrelated refactors are deferred. A change
does not become freeze-safe merely because it is small.

These rules remain the historical release policy for `v1.0.0`. Any later
change belongs to a separately approved version and must not rewrite the
stable checkpoint.
