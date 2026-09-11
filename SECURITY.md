# Security Policy

## Supported versions

This repository ships **scripts and documentation**, not a hosted service.
Fixes land on the `main` branch; use the latest commit or the newest tagged
release.

## Reporting a vulnerability

**Do not open a public issue.** Report privately via GitHub's
[Report a vulnerability](https://github.com/Amz34/selfhosted-agent-stack/security/advisories/new)
form (Security → Advisories → Report a vulnerability).

Please include:

- affected file(s) and version/commit,
- a minimal reproduction (command + config shape, with secrets redacted),
- the impact you believe it has (privilege escalation, data exposure, denial of service),
- any suggested mitigation.

You can expect an acknowledgement within a few days. Credit is given in the
release notes unless you prefer to stay anonymous.

## Scope notes for operators

These scripts run on your infrastructure with your privileges. Before deploying:

- **Review every script before running it**, especially anything executed with `sudo`.
- **Never commit `.env` files or tokens.** Load secrets from environment variables
  or a secret manager; keep files at mode `600`.
- **Keep one credential scope per component.** A bot token, API key or OAuth client
  used by an agent should be dedicated to that agent — shared tokens turn a single
  compromise into a full-stack one, and produce hard-to-debug runtime conflicts.
- **Rotate on suspicion, not on schedule** — but do rotate after any suspected leak;
  a secret deleted from a working tree is still recoverable from git history.
- **Treat inbound webhooks as hostile input.** Validate signatures, bound payload
  sizes, and never pass webhook content straight into a shell.

No script in this repository phones home, collects telemetry, or contacts any host
other than the ones you explicitly configure.
