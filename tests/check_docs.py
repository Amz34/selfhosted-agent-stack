#!/usr/bin/env python3
"""Docs gate for CI: required files exist, README references real paths,
and every relative markdown link/image resolves inside the repo."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

REQUIRED = [
    "README.md",
    "LICENSE",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "CODE_OF_CONDUCT.md",
    "assets/architecture.svg",
    ".github/workflows/ci.yml",
    "docs/selfhosted-agent-stack.md",
    "docs/telegram-bot-patterns.md",
]

LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")

errors: list[str] = []

for rel in REQUIRED:
    if not (ROOT / rel).is_file():
        errors.append(f"missing required file: {rel}")

md_files = sorted(ROOT.glob("*.md")) + sorted((ROOT / "docs").glob("*.md"))
if not md_files:
    errors.append("no markdown files found")

count = 0
for md in md_files:
    for target in LINK_RE.findall(md.read_text(encoding="utf-8")):
        target = target.strip().split(" ")[0]
        if target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        count += 1
        path = (md.parent / target.split("#")[0]).resolve()
        if not path.exists():
            errors.append(f"{md.relative_to(ROOT)}: broken link -> {target}")

script_count = len(list((ROOT / "scripts").glob("*.sh"))) + len(
    list((ROOT / "scripts").glob("*.py"))
)
if script_count == 0:
    errors.append("no scripts found under scripts/")

print(f"checked {len(md_files)} markdown files, {count} relative links, {script_count} scripts")
if errors:
    print("\nFAILED:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
print("docs gate: PASS")
