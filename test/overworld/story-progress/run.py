#!/usr/bin/env python3
"""Compile/run the production resolver with host save-bank accessors."""
from pathlib import Path
import os
import re
import shlex
import sys
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
compiler = shlex.split(os.environ.get("CC", "cc"))
if sys.platform == "darwin" and "CC" not in os.environ and "SDKROOT" not in os.environ:
    # Pair Xcode's compiler with its own SDK; a separately upgraded CLT SDK
    # can be too new for the selected Xcode linker (TAPI architecture errors).
    clang = Path(subprocess.check_output(["xcrun", "--find", "clang"], text=True).strip())
    for parent in clang.parents:
        if parent.name == "Developer":
            sdk = parent / "Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
            if sdk.is_dir():
                compiler = [str(clang), "-isysroot", str(sdk)]
            break
with tempfile.TemporaryDirectory(prefix="pw-story-") as scratch:
    binary = Path(scratch) / "story-test"
    subprocess.run([*compiler, "-DALL_REGIONS=1", "-std=gnu17", "-Wall", "-Wextra",
                    "-Werror", "-I", str(HERE / "shim"), "-I", str(ROOT / "include"),
                    str(HERE / "test.c"), "-o", str(binary)], check=True)
    result = subprocess.check_output([str(binary)], text=True)
    covered = set(re.findall(r'^COVERED (.+)$', result, re.M))
    sources = [ROOT/'src/story_progress.c', *sorted((ROOT/'src/data/story_progress').glob('*.inc'))]
    authored = {objective for source in sources for objective in
                re.findall(r'STORY_OBJECTIVE\(\s*\w+,\s*"([^"]+)"', source.read_text())}
    missing = authored - covered
    if missing:
        raise SystemExit('Untested objective IDs: ' + ', '.join(sorted(missing)))
    print(result.splitlines()[-1])
    print(f'All {len(authored)} authored objectives exercised against production C')
