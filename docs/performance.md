# Performance and Stability

Termux Neo renders once in the foreground and exits. It does not start a
daemon, refresh loop, persistent child process, or background job. Task 27
verifies that contract with repeated fixed-input renders and an interleaved
before/after startup measurement on the reference device.

## Runtime work

One ordinary render performs these bounded phases:

1. Read and validate settings and the selected built-in theme.
2. Read terminal width.
3. Collect device, network, VPN, battery, time, and working-directory values.
4. Calculate Dashboard, Status, and Prompt layout.
5. Assemble the complete output, print it once, and exit.

The primary network interface is cached only for one render or diagnostic
cycle. The cache is cleared immediately afterward, including an unavailable
result, so repeated invocations cannot reuse stale network state. Battery
selection uses the same cycle-local rule for diagnostics.

`termux-battery-status` and `dumpsys battery` cross IPC boundaries and are
therefore run through GNU `timeout` with a two-second TERM ceiling and a
one-second kill-after boundary. A timeout is silent and continues through the
existing sysfs or unavailable fallback. Local `getprop`, `ip`, `ifconfig`,
sysfs, `date`, and `tput` paths were reviewed separately; they remain
synchronous foreground probes with no retry loop.

If `timeout` is unavailable, IPC probes are skipped instead of running
unbounded. Missing commands and missing sysfs sources go directly to safe
fallbacks and do not sleep.

## Portable stability gate

Run:

```bash
bash scripts/performance-check.sh --self-test
```

The self-test sources the production render path and executes 25 fixed-input
renders in one Bash process. Every output must match byte-for-byte. Direct
children, shell jobs, and the process file-descriptor count are inspected
before and after the run.

`tests/test_performance.sh` also proves that a prepared network or battery
probe is reused within one cycle, cleared between cycles, missing sources do
not invoke optional commands, and both IPC probes use the timeout boundary.
The canonical quality runner executes this portable coverage, but CI does not
claim reference-device timing.

## Reference-device measurement

The Task 27 apply workflow creates a private archive snapshot of the verified
Task 26 commit. On the Samsung `SM-N920C` running Android `11`,
`scripts/performance-check.sh --record` then compares that snapshot with the
Task 27 working tree.

The measurement uses:

- three warm-up renders per source;
- fifteen measured renders per source;
- alternating baseline-first and candidate-first rounds;
- the same home, terminal geometry, settings, output validation, and outer
  failure-safety ceiling for both sources;
- Bash `EPOCHREALTIME` wall-clock values, including process startup and
  complete render output.

The startup budget is calculated only after collecting the Task 26 samples.
It is the larger of the observed Task 26 maximum and the outer Tukey fence
`Q3 + 3 × IQR`. Task 27 passes only when its median does not exceed the Task
26 p95 and its p95 does not exceed that measurement-derived budget.
No fixed millisecond target was chosen before measurement.

The resulting device, methodology, aggregate samples, derived budget, and
stability evidence are stored in
[performance-baseline.md](performance-baseline.md). The values are evidence
for this reference device and software state, not a promise for unmeasured
devices or future releases.

The ten-second benchmark harness ceiling and the two-second IPC probe ceiling
are failure-safety limits. Neither is presented as a startup performance
budget.
