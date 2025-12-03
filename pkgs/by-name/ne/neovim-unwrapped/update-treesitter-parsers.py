#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3

import re
import subprocess
from pathlib import Path

parsers = {}
dir = Path(__file__).parent

# Fetch neovim source
src = subprocess.check_output(
    [
        "nix-build",
        dir.parent.parent.parent.parent,
        "-A",
        "neovim-unwrapped.src",
        "--no-out-link",
    ],
    text=True,
).strip()

# Parse build.zig.zon to extract tree-sitter parser dependencies
with open(f"{src}/build.zig.zon") as f:
    content = f.read()

    # Find all treesitter_* dependencies
    # Pattern matches entries like:
    # .treesitter_c = {
    #     .url = "git+https://github.com/tree-sitter/tree-sitter-c?ref=v0.24.1#hash",
    #     .hash = "...",
    # },
    pattern = re.compile(
        r'\.treesitter_(\w+)\s*=\s*\{[^}]*\.url\s*=\s*"([^"]+)"[^}]*\.hash\s*=\s*"([^"]+)"',
        re.MULTILINE | re.DOTALL,
    )

    for match in pattern.finditer(content):
        lang = match.group(1)
        url = match.group(2)
        hash = match.group(3)

        # Extract version from URL (format: git+...?ref=vX.Y.Z#commit or similar)
        # Example: git+https://github.com/tree-sitter/tree-sitter-c?ref=v0.24.1#hash
        version_match = re.search(r"\?ref=([^#]+)", url)
        if not version_match:
            continue

        version = version_match.group(1)

        # Extract repo from URL
        repo_match = re.search(r"github\.com/([^?]+)", url)
        if not repo_match:
            continue

        repo = repo_match.group(1)

        parsers[lang] = {
            "repo": repo,
            "version": version,
            "hash": hash,
        }

# Note: Tree-sitter parsers are now managed directly by the Zig build system
# via build.zig.zon dependencies. The Zig build system handles downloading
# and building these parsers automatically.
#
# This script is kept for reference but tree-sitter-parsers.nix is no longer used.
# The parsers are built as part of the main neovim build process.

print("Tree-sitter parsers found in build.zig.zon:")
for lang, info in parsers.items():
    print(f"  {lang}: {info['repo']} @ {info['version']}")
    print(f"    hash: {info['hash']}")

print("\nNote: With the Zig build system, tree-sitter parsers are managed")
print("automatically via build.zig.zon and don't need a separate .nix file.")
