#!/usr/bin/env python3
"""Scan dotfiles for secrets before they reach GitHub, and for AI-redaction damage.

Modes:
  --staged   scan content staged for commit (used by the pre-commit hook)
  --tree     scan tracked files in the working tree
  --history  scan every blob reachable from HEAD and origin

Exit codes: 0 clean, 1 findings that should block the commit.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

BLOCK = "BLOCK"
WARN = "WARN"

# (label, compiled pattern, severity)
PATTERNS: list[tuple[str, re.Pattern[str], str]] = [
    ("private key block", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), BLOCK),
    ("AWS access key id", re.compile(r"\bAKIA[0-9A-Z]{16}\b"), BLOCK),
    ("GitHub token", re.compile(r"\b(gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})\b"), BLOCK),
    ("Slack token", re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}\b"), BLOCK),
    ("OpenAI-style key", re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b"), BLOCK),
    ("Google API key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"), BLOCK),
    ("OpenRouter key", re.compile(r"\bsk-or-v1-[A-Za-z0-9]{32,}\b"), BLOCK),
    ("Anthropic key", re.compile(r"\bsk-ant-[A-Za-z0-9_-]{20,}\b"), BLOCK),
    ("assigned secret", re.compile(
        r"(?i)\b(api[_-]?key|secret|passwd|password|token|bearer)\b\s*[:=]\s*"
        r"[\"']?(?!\$\{|\$[A-Za-z_]|\[|<|xxxx|your|example|placeholder)[^\s\"']{8,}"), BLOCK),
    ("email address", re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"), WARN),
    ("absolute home path", re.compile(r"/home/(?!<user>)[A-Za-z0-9._-]+"), WARN),
    ("hardcoded IPv4", re.compile(r"\b(?!127\.0\.0\.1|0\.0\.0\.0)(\d{1,3}\.){3}\d{1,3}\b"), WARN),
    # Catches the exact damage class that corrupted .zshrc: an AI scanner
    # replacing real text with a placeholder token.
    ("AI redaction placeholder", re.compile(r"\[(PERSON_NAME|ADDRESS|EMAIL|PHONE_NUMBER|IP_ADDRESS|USER_NAME|SECRET|API_KEY|REDACTED)\]"), BLOCK),
]

SKIP_SUFFIXES = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".ico",
    ".mp4", ".webm", ".mp3", ".woff", ".woff2", ".ttf", ".otf",
    ".zip", ".gz", ".xz", ".pdf", ".lock",
}
SKIP_DIRS = {".git", "node_modules", "__pycache__", ".venv"}


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], capture_output=True, text=True, check=False
    ).stdout


def staged_files() -> list[str]:
    out = git("diff", "--cached", "--name-only", "--diff-filter=ACMR")
    return [f for f in out.splitlines() if f]


def tree_files() -> list[str]:
    return [f for f in git("ls-files").splitlines() if f]


def history_blobs() -> list[tuple[str, str]]:
    """(object_name, display_path) for every distinct blob in history."""
    out = git("rev-list", "--objects", "HEAD", "origin/main", "origin/HEAD")
    seen: dict[str, str] = {}
    for line in out.splitlines():
        sha, _, path = line.partition(" ")
        if path and sha not in seen:
            seen[sha] = path
    return list(seen.items())


def should_skip(path: str) -> bool:
    p = Path(path)
    if any(part in SKIP_DIRS for part in p.parts):
        return True
    return p.suffix.lower() in SKIP_SUFFIXES


def scan_text(text: str, label: str, findings: list[tuple[str, str, int, str]]) -> None:
    for lineno, line in enumerate(text.splitlines(), 1):
        if len(line) > 2000:
            continue
        for name, pat, sev in PATTERNS:
            m = pat.search(line)
            if not m:
                continue
            hit = m.group(0)
            if name == "assigned secret" and ("$" in hit or "{{" in hit):
                continue
            findings.append((sev, name, lineno, f"{label}:{lineno}: {name}"))


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--staged", action="store_true")
    g.add_argument("--tree", action="store_true")
    g.add_argument("--history", action="store_true")
    args = ap.parse_args()

    findings: list[tuple[str, str, int, str]] = []

    if args.staged:
        for path in staged_files():
            if should_skip(path):
                continue
            blob = git("show", f":{path}")
            scan_text(blob, path, findings)
    elif args.tree:
        for path in tree_files():
            if should_skip(path):
                continue
            p = Path(path)
            if p.is_file():
                scan_text(p.read_text(errors="replace"), path, findings)
    else:
        for sha, path in history_blobs():
            if should_skip(path):
                continue
            blob = git("cat-file", "-p", sha)
            scan_text(blob, f"{path}@{sha[:8]}", findings)

    blocks = [f for f in findings if f[0] == BLOCK]
    warns = [f for f in findings if f[0] == WARN]

    if blocks:
        print("SECRET SCAN: blocking findings\n")
        for _, _, _, msg in blocks:
            print(f"  BLOCK  {msg}")
    if warns:
        print("\nSECRET SCAN: review these\n")
        for _, _, _, msg in warns:
            print(f"  WARN   {msg}")
    if not findings:
        print("SECRET SCAN: clean")
        return 0

    print(f"\n{len(blocks)} blocking, {len(warns)} warnings")
    return 1 if blocks else 0


if __name__ == "__main__":
    sys.exit(main())
