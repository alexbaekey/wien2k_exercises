#!/usr/bin/env python3

from pathlib import Path
import re


CASES = ["Si", "GaAs", "InAs"]

RUNS = [
    ("PBE noSOC", "1_PBE_noSOC"),
    ("PBE withSOC", "2_PBE_SOC"),
    ("HSE noSOC", "3_HSE_noSOC"),
    ("HSE withSOC", "4_HSE_SOC"),
]

OUTPUT_FILE = "runtimes.md"

def parse_wall_time_to_seconds(t):
    """
    Convert WIEN2k dayfile wall time strings to seconds.

    Examples:
        0:00.34      -> 0.34 seconds
        1:23.45      -> 83.45 seconds
        4:41.62      -> 281.62 seconds
        1:02:03.45   -> 3723.45 seconds
    """

    parts = t.split(":")

    if len(parts) == 2:
        minutes = int(parts[0])
        seconds = float(parts[1])
        return 60 * minutes + seconds

    if len(parts) == 3:
        hours = int(parts[0])
        minutes = int(parts[1])
        seconds = float(parts[2])
        return 3600 * hours + 60 * minutes + seconds

    return 0.0


def get_dayfile_time_minutes(dayfile):
    dayfile = Path(dayfile)

    if not dayfile.exists():
        return None

    total_seconds = 0.0

    # matches wall time after user/sys CPU times:
    # 1.059u 0.031s 0:00.34
    pattern = re.compile(r"\s+\d+\.\d+u\s+\d+\.\d+s\s+([0-9:]+\.[0-9]+)")

    with open(dayfile, "r", errors="ignore") as f:
        for line in f:
            if not line.startswith(">"):
                continue

            m = pattern.search(line)
            if m:
                total_seconds += parse_wall_time_to_seconds(m.group(1))

    return total_seconds / 60.0


#def main():
#    print("")
#    print("| SCF time (minutes) | Si | GaAs | InAs |")
#    print("|---|---:|---:|---:|")
#
#    for label, dirname in RUNS:
#        row = []
#        for case in CASES:
#            dayfile = Path(dirname) / case / case / f"{case}.dayfile"
#            minutes = get_dayfile_time_minutes(dayfile)
#            if minutes is None:
#                row.append("missing")
#            else:
#                row.append(f"{minutes:.2f}")
#        print(f"| {label} | {row[0]} | {row[1]} | {row[2]} |")
#    print("")

def main():
    lines = []

    lines.append("# SCF runtimes")
    lines.append("")
    lines.append("| SCF time (minutes) | Si | GaAs | InAs |")
    lines.append("|---|---:|---:|---:|")

    for label, dirname in RUNS:
        row = []

        for case in CASES:
            dayfile = Path(dirname) / case / case / f"{case}.dayfile"
            minutes = get_dayfile_time_minutes(dayfile)

            if minutes is None:
                row.append("missing")
            else:
                row.append(f"{minutes:.2f}")

        lines.append(f"| {label} | {row[0]} | {row[1]} | {row[2]} |")

    text = "\n".join(lines) + "\n"

    print(text)

    with open(OUTPUT_FILE, "w") as f:
        f.write(text)

    print(f"Saved table to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
