# Reference Performance Baseline

This file is generated on the verified reference device by `scripts/performance-check.sh`. It records Task 26 and Task 27 startup measurements taken in one interleaved run.

## Environment

- Manufacturer: `samsung`
- Model: `SM-N920C`
- Android release: `11`
- Bash: `5.3.9`
- Baseline source: Task 26 checkout at `task26-3fe6e7c`
- Candidate source: Task 27 working tree
- Warm-up runs per source: `3`
- Measured runs per source: `15`
- Ordering: interleaved and alternated by round
- Metric: elapsed wall-clock time from Bash `EPOCHREALTIME`, including process startup and render output

## Measurements

| Source | Min | Median | p95 | Max |
| --- | ---: | ---: | ---: | ---: |
| Task 26 baseline | 3323.243 ms | 3473.519 ms | 3592.718 ms | 3592.718 ms |
| Task 27 candidate | 2252.184 ms | 2452.625 ms | 2580.596 ms | 2580.596 ms |

The measured startup budget is `4074.070 ms`. It is the larger of the observed Task 26 maximum and its outer Tukey fence (`Q3 + 3 × IQR`). No fixed millisecond target was chosen before measurement.

Acceptance requires the Task 27 median not to exceed the Task 26 p95, and the Task 27 p95 not to exceed the measurement-derived budget.

```text
Task 27 median <= Task 26 p95: PASS
Task 27 p95 <= measured budget: PASS
Fixed-input repeated renders: PASS (25 exact runs)
Persistent child processes after render: 0
Background jobs after render: 0
File descriptors before/after: 4 / 4
```

The `10s` benchmark harness ceiling and the runtime `2s` IPC probe ceiling are failure-safety limits, not startup performance budgets.
