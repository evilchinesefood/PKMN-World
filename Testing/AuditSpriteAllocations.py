#!/usr/bin/env python3
"""List asserting sprite allocations followed by nearby MAX_SPRITES guards.

Read-only review aid, not a validator or a C control-flow analysis. It misses
wrapper-mediated calls and distant guards, and cannot establish safe recovery.
Run from any directory; output is TSV suitable for further review.
"""

import re
from pathlib import Path


def main():
    root = Path(__file__).resolve().parent.parent
    print("file\tline\tallocator\tvariable")
    for path in sorted((root / "src").glob("*.c")):
        # Preserve positions while excluding comments and quoted text.
        source = path.read_text()
        source = re.sub(
            r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',
            lambda match: re.sub(r"[^\n]", " ", match.group()),
            source,
            flags=re.S,
        )
        for match in re.finditer(
            r"(?P<var>\*?\b\w+)\s*=\s*(?P<call>CreateSprite(?:AtEnd)?)\(", source
        ):
            depth = 1
            end = match.end()
            while depth and end < len(source):
                depth += (source[end] == "(") - (source[end] == ")")
                end += 1
            # Restrict to the next eight lines. These are candidates, even if
            # another assignment changes the variable before the comparison.
            nearby = "\n".join(source[end:].split("\n")[:9])
            operand = re.escape(match["var"])
            if re.search(r"(?<!\w)" + operand + r"\s*(?:==|!=|>=|<)\s*MAX_SPRITES\b", nearby):
                line = source.count("\n", 0, match.start()) + 1
                print(f"{path.relative_to(root)}\t{line}\t{match['call']}\t{match['var']}")


if __name__ == "__main__":
    main()
