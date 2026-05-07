#!/usr/bin/env python3

import sys
import re

if len(sys.argv) != 3:
    print("Usage: python3 patch_inhf_nband.py case.inhf nband")
    sys.exit(1)

filename = sys.argv[1]
nband = sys.argv[2]

with open(filename, "r") as f:
    lines = f.readlines()

new_lines = []
changed = False

for line in lines:
    lower = line.lower()

    if "nband" in lower and not changed:
        line2 = re.sub(
            r"^(\s*)(xx|XX|[-+]?\d+)",
            r"\g<1>" + nband,
            line,
            count=1,
        )

        if line2 != line:
            line = line2
            changed = True

    new_lines.append(line)

if not changed:
    print(f"ERROR: could not patch nband line in {filename}")
    print("")
    print("File contents with line numbers:")
    for i, line in enumerate(lines, start=1):
        print(f"{i:4d}: {line.rstrip()}")
    sys.exit(1)

with open(filename, "w") as f:
    f.writelines(new_lines)

print(f"Patched {filename}: nband = {nband}")
