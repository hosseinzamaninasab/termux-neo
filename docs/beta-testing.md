# Stable Release Verification

Termux Neo `1.0.0` preserves the feature-frozen release-candidate behavior.
Stable verification validates the existing product and release lifecycle; it
does not expand product scope.

## Safe field command

From a complete source tree or verified extracted release artifact:

```bash
bash scripts/beta-field-test.sh --self-test
```

The portable self-test uses a temporary, isolated HOME and PREFIX. It covers:

- clean install and an install with existing settings;
- update from `0.4.0-alpha`;
- uninstall with settings preserved and explicitly removed;
- startup with every network and battery source absent;
- startup when optional probes return permission errors;
- fixed portrait and landscape widths;
- fresh-environment behavior under `env -i`.

It does not change the user's installed runtime, settings, or `.bashrc`.

## Real-device record

On a real Termux device, use an output path outside the release tree:

```bash
bash scripts/beta-field-test.sh --record \
    "$HOME/storage/downloads/Telegram/task32-device-report.md"
```

Record mode builds and verifies the stable artifact, runs its smoke and
repeated-render checks, and exercises the same lifecycle in isolated paths.
It pauses twice: rotate the device to portrait and then landscape, waiting for
Termux to resize before pressing Enter each time.

The generated Markdown contains only device model, Android and Bash versions,
terminal widths, aggregate PASS/FAIL results, and defect counts. For this
stable release it is release evidence only when the reference device is
`samsung` `SM-N920C` on Android `11`. It excludes HOME, PREFIX, usernames,
local IP addresses, settings values, and raw rendered device data. Review the
file before sharing it.

One report supports only its recorded environment. Additional devices can be
added only through separately retained reports; their absence must not be
rewritten as a broad Android or Termux compatibility claim.

## Feedback

Before filing a stable-release issue:

1. Verify the artifact's external checksum and internal manifest.
2. Record `termux-neo --version`.
3. Run `termux-neo --diagnose` and review the output for private information.
4. State whether install, update, uninstall, or render-once behavior is
   affected.
5. Include minimal reproduction steps and the exact exit status.
6. Redact usernames, local paths, IP addresses, and unrelated terminal output.

Accepted issues follow [beta-issues.md](beta-issues.md). Feature requests are
recorded as enhancements and require a separately approved post-1.0 milestone.
The completed release boundary is recorded in
[feature-freeze.md](feature-freeze.md).
