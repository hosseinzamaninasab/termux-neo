# Security Policy

## Supported version

| Version | Security fixes |
| --- | --- |
| `1.0.0` | Current supported stable release |
| `1.0.0-rc.1` | Superseded by the stable release |
| `0.9.0-beta` | Superseded |
| Earlier development checkpoints | Not supported |

Security fixes require focused regression coverage, the full quality pipeline,
the release-artifact gate, and a separately versioned release.

## Report privately

Do not open a public issue with exploit details, private paths, local IP
addresses, tokens, or other sensitive evidence.

Preferred reporting route:

1. Use GitHub's **Private vulnerability reporting** for this repository when
   that option is available.
2. If the private form is unavailable, contact the maintainer through an
   already established private channel and identify the
   `hosseinzamaninasab/termux-neo` repository. Do not send credentials.

No public security email address is asserted by this checkpoint, and no fixed
response-time SLA is promised.

## Include

- affected Termux Neo version and artifact checksum;
- affected command or lifecycle phase;
- device model, Android release, and Termux provenance when relevant;
- minimal reproduction steps and exact exit status;
- expected versus observed behavior;
- whether settings, filesystem ownership, startup, terminal-control handling,
  release integrity, or private diagnostic data is involved;
- a safe proof of concept with secrets and unrelated user data removed.

## Coordinated handling

The maintainer should confirm the report privately, reproduce it, classify its
release impact, develop a minimal fix, add a regression, and verify the full
pipeline before disclosure. A security issue is closed only with repeatable
verification.

Do not test by damaging another person's device, installation, account, or
data. Do not bypass access controls or broaden collection beyond what is
needed to prove the issue.

The reviewed technical boundary is documented in
[Security and Failure-Safety Review](security.md). Non-security defects follow
the [Public Beta Issue Ledger](beta-issues.md).
