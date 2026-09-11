## What this changes

<!-- One or two sentences. What failure mode or gap does it address? -->

## Why

<!-- The operational problem. Link the issue: Closes #123 -->

## Evidence

<!-- Before/after measurements, log excerpts, or the incident this prevents. -->

| Metric | Before | After |
|---|---|---|
| | | |

## Checklist

- [ ] Safe by default — destructive paths need an explicit flag and support `--dry-run`
- [ ] Idempotent — running it twice changes nothing the second time
- [ ] Silent when healthy — no output unless it acts or something is wrong
- [ ] No secrets, tokens, real emails, hostnames or IPs committed
- [ ] English only in code, comments and docs
- [ ] Docs updated (README table / `docs/`) if files were added or removed
- [ ] `CHANGELOG.md` entry added under **Unreleased**

## Local validation

```bash
for f in scripts/*.sh; do bash -n "$f"; done
python3 -m compileall -q scripts
python3 tests/check_docs.py
```

<!-- Paste the output above. CI runs the same checks. -->
