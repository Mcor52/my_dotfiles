#!/usr/bin/env python3
"""Scan dotfiles for secrets / PII before they reach a public repo, and for
AI-redaction damage.

Modes:
  --staged          content staged for commit (used by the pre-commit hook)
  --tree            tracked files in the working tree
  --history         every blob reachable from all refs
  --path <p>...     scan arbitrary files/dirs (for vetting NOT-yet-added files)

Exit codes: 0 clean, 1 blocking findings.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

BLOCK = "BLOCK"
WARN = "WARN"

PATTERNS: list[tuple[str, re.Pattern[str], str]] = [
    # --- credentials -------------------------------------------------------
    ("private key block", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), BLOCK),
    ("putty private key", re.compile(r"PuTTY-User-Key-File-\d"), BLOCK),
    ("pgp private key", re.compile(r"-----BEGIN PGP PRIVATE KEY BLOCK-----"), BLOCK),
    ("aws access key id", re.compile(r"\b(AKIA|ASIA)[0-9A-Z]{16}\b"), BLOCK),
    ("github token", re.compile(r"\b(gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})\b"), BLOCK),
    ("slack token", re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}\b"), BLOCK),
    ("discord bot token", re.compile(r"\b[MNO][A-Za-z0-9_-]{23,}\.[A-Za-z0-9_-]{6}\.[A-Za-z0-9_-]{27,}\b"), BLOCK),
    ("discord webhook", re.compile(r"discord(?:app)?\.com/api/webhooks/\d+/[A-Za-z0-9_-]+"), BLOCK),
    ("stripe key", re.compile(r"\b(sk|rk)_(live|test)_[A-Za-z0-9]{20,}\b"), BLOCK),
    ("sendgrid key", re.compile(r"\bSG\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\b"), BLOCK),
    ("twilio sid", re.compile(r"\bAC[0-9a-fA-F]{32}\b"), BLOCK),
    ("npm token", re.compile(r"\bnpm_[A-Za-z0-9]{36}\b"), BLOCK),
    ("pypi token", re.compile(r"\bpypi-[A-Za-z0-9_-]{50,}\b"), BLOCK),
    ("gitlab token", re.compile(r"\bglpat-[A-Za-z0-9_-]{20,}\b"), BLOCK),
    ("digitalocean token", re.compile(r"\bdop_v1_[0-9a-f]{64}\b"), BLOCK),
    ("jwt", re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"), BLOCK),
    ("openai-style key", re.compile(r"\b(sk|rk)-[A-Za-z0-9_-]{20,}\b"), BLOCK),
    ("anthropic key", re.compile(r"\bsk-ant-[A-Za-z0-9_-]{20,}\b"), BLOCK),
    ("huggingface token", re.compile(r"\bhf_[A-Za-z0-9]{30,}\b"), BLOCK),
    ("google api key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"), BLOCK),
    ("google oauth secret", re.compile(r"\bGOCSPX-[A-Za-z0-9_-]{20,}\b"), BLOCK),
    ("tailscale key", re.compile(r"\btskey-[a-z]+-[A-Za-z0-9]{20,}\b"), BLOCK),
    ("age secret key", re.compile(r"\bAGE-SECRET-KEY-1[A-Z0-9]{20,}\b"), BLOCK),
    # --- generic assignment ------------------------------------------------
    ("assigned secret", re.compile(
        r"(?i)\b(api[_-]?key|apikey|secret[_-]?key|client[_-]?secret|access[_-]?token|"
        r"auth[_-]?token|refresh[_-]?token|private[_-]?key|passwd|password|token|bearer)\b"
        r"\s*[:=]\s*[\"']?(?!\$\{|\$[A-Za-z_]|\(|\[|<|xxxx|your|example|placeholder|none|null|true|false)"
        r"[^\s\"',]{8,}"), BLOCK),
    ("secret in url", re.compile(r"https?://[^\s/@]+:[^\s/@]+@[^\s/]+"), BLOCK),
    # --- PII ----------------------------------------------------------------
    ("absolute home path", re.compile(r"/(home|Users)/(?!<user>|\$|%|USER\b)[A-Za-z0-9._-]+"), WARN),
    ("hardcoded IPv4", re.compile(r"\b(?!127\.0\.0\.1|0\.0\.0\.0|1\.1\.1\.1)(\d{1,3}\.){3}\d{1,3}\b"), WARN),
    ("private-range ip", re.compile(r"\b(?:10|192\.168|172\.(?:1[6-9]|2\d|3[01]))\.\d+\.\d+\b"), WARN),
    ("mac address", re.compile(r"\b([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b"), WARN),
    ("email address", re.compile(
        r"\b[A-Za-z0-9._%+-]+@(?!users\.noreply\.github\.com)"
        r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.(?!png|jpg|jpeg|gif|svg|webp|ico|css|js|woff2?|ttf)(?:[A-Za-z]{2,})\b"), WARN),
    ("us phone", re.compile(r"\b(?:\+1[-. ]?)?\(?\d{3}\)?[-. ]\d{3}[-. ]\d{4}\b"), WARN),
    ("uuid/device id", re.compile(r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b"), WARN),
    # --- redaction damage ----------------------------------------------------
    ("ai redaction placeholder", re.compile(
        r"\[(PERSON_NAME|ADDRESS|EMAIL|PHONE_NUMBER|IP_ADDRESS|USER_NAME|USERNAME|SECRET|"
        r"API_KEY|REDACTED|NAME|LOCATION|ORGANIZATION)\]"), BLOCK),
    ("ai redaction angle", re.compile(r"<(PERSON_NAME|ADDRESS|REDACTED|EMAIL|PHONE_NUMBER)>"), BLOCK),
    ("ai redaction curly", re.compile(r"\{(PERSON_NAME|ADDRESS|REDACTED|EMAIL)\}"), BLOCK),
]

SKIP_SUFFIXES = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".ico", ".bmp", ".tiff",
    ".mp4", ".webm", ".mkv", ".mov", ".mp3", ".flac", ".wav", ".ogg",
    ".woff", ".woff2", ".ttf", ".otf", ".eot",
    ".zip", ".gz", ".xz", ".bz2", ".tar", ".7z", ".rar",
    ".pdf", ".lock", ".so", ".a", ".o", ".bin", ".exe", ".dll", ".dylib",
    ".db", ".sqlite", ".sqlite3", ".pyc", ".class", ".jar", ".appimage",
}
SKIP_DIRS = {".git", "node_modules", "__pycache__", ".venv", ".cache", "venv", "target", "dist", "build"}

# Public third-party code we vendor; its bundled sample tokens are not ours.
ALLOWLIST_PATHS = {
    "Configs/Spotify/Spicetify/CustomApps/lyrics-plus/index.js",
    "Configs/Spotify/Spicetify/Extensions/popupLyrics.js",
}

# This file holds the patterns themselves, so its rule-definition lines always
# match. Skip those lines only, so a real key pasted into this file is still caught.
SELF_PATH = "Scripts/leak-guard.py"

# Identity strings that must never appear in a public repo.
REAL_IDENTITIES = ["matteocormier", "matteo cormier"]


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=False).stdout


def repo_root() -> Path:
    out = git("rev-parse", "--show-toplevel").strip()
    return Path(out) if out else Path.cwd()


def staged_files() -> list[str]:
    return [f for f in git("diff", "--cached", "--name-only", "--diff-filter=ACMR").splitlines() if f]


def tree_files() -> list[str]:
    return [f for f in git("ls-files").splitlines() if f]


def history_blobs() -> list[tuple[str, str]]:
    out = git("rev-list", "--objects", "--all")
    seen: dict[str, str] = {}
    for line in out.splitlines():
        sha, sep, path = line.partition(" ")
        if sep and sha not in seen:
            seen[sha] = path
    return list(seen.items())


def should_skip(path: str, allow: bool = True) -> bool:
    if allow and path in ALLOWLIST_PATHS:
        return True
    p = Path(path)
    if any(part in SKIP_DIRS for part in p.parts):
        return True
    return p.suffix.lower() in SKIP_SUFFIXES


def looks_binary(text: str) -> bool:
    if "\x00" in text[:4096]:
        return True
    sample = text[:4096]
    if not sample:
        return False
    return sum(1 for c in sample if ord(c) < 9 or 13 < ord(c) < 32) / len(sample) > 0.05


def scan_text(text: str, label: str, findings: list[tuple[str, str, int, str]]) -> None:
    if looks_binary(text):
        return
    # history labels are "path@sha"; strip the suffix before matching so this
    # file's own rule definitions stay exempt (they match by construction).
    self_scan = label.split("@", 1)[0].endswith(SELF_PATH)
    in_rules = False
    for lineno, line in enumerate(text.splitlines(), 1):
        if len(line) > 4000:
            continue
        if self_scan:
            # Skip the rule-definition blocks in this file, which match the rules
            # by construction. Everything else is still scanned, so a real key
            # pasted into this file is still caught.
            if not in_rules and line.startswith(("PATTERNS", "REAL_IDENTITIES")):
                in_rules = True
                continue
            if in_rules:
                if line.startswith("]"):
                    in_rules = False
                continue
        low = line.lower()
        for ident in REAL_IDENTITIES:
            if ident in low:
                findings.append((BLOCK, "real identity", lineno,
                                 f"{label}:{lineno}: real identity '{ident}'"))
        for name, pat, sev in PATTERNS:
            m = pat.search(line)
            if not m:
                continue
            hit = m.group(0)
            if name == "assigned secret" and ("$" in hit or "{{" in hit):
                continue
            findings.append((sev, name, lineno, f"{label}:{lineno}: {name} -> {hit[:60]}"))


def scan_paths(paths: list[str], findings: list[tuple[str, str, int, str]]) -> None:
    for raw in paths:
        p = Path(raw)
        targets = [p] if p.is_file() else sorted(p.rglob("*"))
        for f in targets:
            if not f.is_file() or should_skip(str(f), allow=False):
                continue
            try:
                text = f.read_text(errors="replace")
            except OSError:
                continue
            scan_text(text, str(f), findings)


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--staged", action="store_true")
    g.add_argument("--tree", action="store_true")
    g.add_argument("--history", action="store_true")
    g.add_argument("--path", nargs="+", metavar="PATH")
    args = ap.parse_args()

    findings: list[tuple[str, str, int, str]] = []
    root = repo_root()

    if args.staged:
        for path in staged_files():
            if should_skip(path):
                continue
            scan_text(git("show", f":{path}"), path, findings)
    elif args.tree:
        for path in tree_files():
            if should_skip(path):
                continue
            f = root / path
            if f.is_file():
                scan_text(f.read_text(errors="replace"), path, findings)
    elif args.history:
        for sha, path in history_blobs():
            if should_skip(path):
                continue
            scan_text(git("cat-file", "-p", sha), f"{path}@{sha[:8]}", findings)
    else:
        scan_paths(args.path, findings)

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
