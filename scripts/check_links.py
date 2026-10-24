#!/usr/bin/env python3
"""Check that every relative Markdown link in the repository points at an existing file or directory.

usage: scripts/check_links.py [ROOT]      (default: the repository root)

Reads the tracked Markdown files (`*.md`), ignores URLs, mail links, pure anchors and absolute machine paths, strips `#fragment`
and `?query`, and resolves each target against the directory of the file that contains the link.
Exits 1 and prints `file:line: target` for each broken link, so it can run in CI or a pre-commit hook.
"""
import re
import subprocess
import sys
from pathlib import Path

LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)|!\[[^\]]*\]\(([^)\s]+)\)")
SKIP_PREFIXES = ("http://", "https://", "mailto:", "#", "tel:", "data:", "file://", "/")   # "/" and file:// are machine paths, not repository links


def markdown_files(root: Path) -> list[Path]:
    """Return the Markdown files git tracks under `root`, or all `*.md` files when `root` is not a git checkout."""
    try:
        out = subprocess.run(["git", "-C", str(root), "ls-files", "*.md"], capture_output=True, text=True, check=True).stdout
        return [root / line for line in out.splitlines() if line]
    except (OSError, subprocess.CalledProcessError):
        return sorted(root.rglob("*.md"))


def broken_links(root: Path) -> list[tuple[Path, int, str]]:
    """Return `(file, line number, target)` for each relative link whose target does not exist."""
    found = []
    for md in markdown_files(root):
        if not md.is_file():
            continue
        in_fence = False
        for number, line in enumerate(md.read_text(errors="replace").splitlines(), 1):
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            for match in LINK.finditer(line):
                target = match.group(1) or match.group(2)
                if target.startswith(SKIP_PREFIXES):
                    continue
                path = re.split(r"[#?]", target, maxsplit=1)[0]
                if path and not (md.parent / path).exists():
                    found.append((md.relative_to(root), number, target))
    return found


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent).resolve()
    broken = broken_links(root)
    for file, number, target in broken:
        print(f"{file}:{number}: {target}")
    print(f"{len(broken)} broken link(s)")
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
