# Feature Freeze

Status:

```text
ACTIVE — 0.9.0-beta
```

The stable-release branch is frozen at the Task 28 public-beta checkpoint.
Product scope, CLI surface, configuration schema, themes, render geometry, and
lifecycle ownership may not expand before `v1.0.0`.

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

The freeze remains active through public documentation, packaging discipline,
and release-candidate testing. It ends only after the stable `v1.0.0`
checkpoint is verified or the Project Master explicitly revises the release
plan.
