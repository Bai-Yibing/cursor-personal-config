#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Validate UTF-8 text docs; fail on mojibake markers and optional missing CJK."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

CJK_RANGES = (
    (0x4E00, 0x9FFF),
    (0x3400, 0x4DBF),
    (0xF900, 0xFAFF),
)


def has_cjk(text: str) -> bool:
    for ch in text:
        o = ord(ch)
        for a, b in CJK_RANGES:
            if a <= o <= b:
                return True
    return False


def check_file(path: Path, require_cjk: bool) -> list[str]:
    errors: list[str] = []
    raw = path.read_bytes()
    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        errors.append("utf16_bom")
    if raw.startswith(b"\xef\xbb\xbf"):
        # BOM is discouraged for our docs but readable; warn as error for gate
        errors.append("utf8_bom")
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as e:
        return [f"utf8_decode:{e}"]
    if "\ufffd" in text:
        errors.append("replacement_char_u+fffd")
    if "????" in text:
        errors.append("question_mark_run")
    # heuristic: many isolated ? where CJK expected is hard; stick to runs
    if require_cjk and not has_cjk(text):
        errors.append("missing_cjk")
    return errors


def iter_files(root: Path, glob: str) -> list[Path]:
    if root.is_file():
        return [root]
    return sorted(p for p in root.rglob(glob) if p.is_file())


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("path", type=Path, help="file or directory")
    ap.add_argument("--glob", default="*.md", help="glob when path is directory")
    ap.add_argument(
        "--require-cjk",
        action="store_true",
        default=True,
        help="require at least one CJK char (default: on)",
    )
    ap.add_argument(
        "--allow-ascii-only",
        action="store_true",
        help="do not require CJK (for English-only files)",
    )
    args = ap.parse_args()
    require_cjk = not args.allow_ascii_only
    files = iter_files(args.path, args.glob)
    if not files:
        print("no_files", file=sys.stderr)
        return 2
    failed = 0
    for p in files:
        errs = check_file(p, require_cjk=require_cjk)
        if errs:
            failed += 1
            print(f"FAIL {p} :: {','.join(errs)}")
        else:
            print(f"OK   {p}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
