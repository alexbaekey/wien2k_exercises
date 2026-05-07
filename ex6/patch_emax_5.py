#!/usr/bin/env python3

import sys
import re

if len(sys.argv) != 2:
    print("Usage: python3 patch_emax_5.py case.in1_or_case.inso")
    sys.exit(1)

filename = sys.argv[1]

with open(filename, "r") as f:
    lines = f.readlines()

new_lines = []
changed = False

for line in lines:
    lower = line.lower()

    # Prefer lines that explicitly mention emax.
    if "emax" in lower and not changed:
        nums = list(
            re.finditer(
                r"[-+]?\d+(?:\.\d*)?(?:[dDeE][-+]?\d+)?",
                line,
            )
        )

        if len(nums) >= 2:
            # Usually line has EMIN, EMAX: replace the second number.
            m = nums[1]
            line = line[:m.start()] + "5.0" + line[m.end():]
            changed = True

        elif len(nums) == 1:
            # If only one number is present, replace it.
            m = nums[0]
            line = line[:m.start()] + "5.0" + line[m.end():]
            changed = True

    new_lines.append(line)

if not changed:
    print(f"WARNING: could not automatically find an explicit EMAX line in {filename}")
    print("Check this file manually and set emax = 5.0 if needed.")
else:
    with open(filename, "w") as f:
        f.writelines(new_lines)

    print(f"Patched {filename}: emax = 5.0")
