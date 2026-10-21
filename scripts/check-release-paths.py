#!/usr/bin/env python3
"""Reject literal build-machine home paths in a release bundle.

This is a packaging regression guard, not a general-purpose secret scanner.
It reports relative filenames and counts, never the matched personal paths.
"""
import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: check-release-paths.py <app-bundle>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1])
    if not root.is_dir():
        print("App bundle does not exist.", file=sys.stderr)
        return 2
    pattern = re.compile(rb"/(?:Users|home)/[^/\x00\s]+")
    findings = []
    count = 0
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        count += 1
        matches = len(pattern.findall(path.read_bytes()))
        if matches:
            findings.append((path.relative_to(root), matches))
    for name, matches in findings:
        print(f"FAIL {name}: {matches} absolute home path(s)", file=sys.stderr)
    if findings:
        return 1
    print(f"Release path check passed: {count} files, no absolute home paths.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
