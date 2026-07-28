#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Write a text file as UTF-8 (no BOM) from base64 or a UTF-8 source file.

Keeps the shell command line ASCII-safe when using --base64.
"""
from __future__ import annotations

import argparse
import base64
import sys
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-o", "--output", type=Path, required=True)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--base64", help="UTF-8 payload encoded as base64")
    g.add_argument("--input", type=Path, help="existing UTF-8 file to copy")
    args = ap.parse_args()

    if args.base64 is not None:
        data = base64.b64decode(args.base64)
        # validate utf-8
        data.decode("utf-8")
    else:
        data = args.input.read_bytes()
        data.decode("utf-8")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(data)
    print(f"wrote {args.output} bytes={len(data)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
