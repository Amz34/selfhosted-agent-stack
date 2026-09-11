# Contributing

Thanks for considering a contribution. This repository collects **operational
knowledge that survived contact with a real system**, so the bar is: does it
work in production, and can someone else safely run it?

## What is most valuable

- **A failure mode we missed** — with the symptom, the diagnosis command, and the fix.
- **A watchdog or reaper improvement** — especially false-positive prevention.
- **A new platform recipe** (a different free tier, a different channel) that follows
  the same "silent when healthy" philosophy.
- **Documentation corrections** — a command that no longer works, a stale number.

## Ground rules for scripts

1. **Safe by default.** Destructive actions require an explicit flag and support
   `--dry-run`. Never kill a process you cannot prove is stale.
2. **Idempotent.** Running it twice must not break anything.
3. **Silent when healthy.** A cron-able script prints output only when it acts or
   when something is wrong. No "all good" walls of text.
4. **Portable.** POSIX-ish bash, no hardcoded paths outside `${HOME}`/env vars,
   no vendor-specific assumptions unless documented.
5. **English only** in code, comments, docs and user-facing output.
6. **No secrets, ever.** No tokens, no real emails, no personal hostnames or IPs.
   Read configuration from environment variables and document them in the README.

## Workflow

```bash
git clone https://github.com/Amz34/selfhosted-agent-stack.git
cd selfhosted-agent-stack
git checkout -b fix/short-description

# validate what CI validates, locally:
for f in scripts/*.sh; do bash -n "$f"; done
python3 -m compileall -q scripts
python3 tests/check_docs.py

git add -A
git commit -m "fix(watchdog): ignore read-only bind mounts when measuring disk"
git push origin fix/short-description
```

Then open a pull request and fill in the template. Conventional-commit style
prefixes (`fix:`, `feat:`, `docs:`, `chore:`) are appreciated.

## Pull request expectations

- One logical change per PR.
- State **what you measured** (before/after numbers beat adjectives).
- Link the issue it closes, if any.
- CI must pass. If a check is genuinely wrong, say so in the PR and propose the fix.

## Reporting bugs

Open an issue using the bug template. Include: OS/distro, host specs (CPU/RAM/disk),
the exact command, the full output, and what you expected. Sanitise hostnames,
tokens and personal data before pasting.

## Security

Do not open a public issue for a vulnerability — see [SECURITY.md](SECURITY.md).
