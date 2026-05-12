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

OUTPUT_FILE = "band_gaps.md"


def get_band_gap_ev(scf_file):
    scf_file = Path(scf_file)

    if not scf_file.exists():
        return None

    gap_line = None

    with open(scf_file, "r", errors="ignore") as f:
        for line in f:
            if ":GAP" in line:
                gap_line = line.strip()

    if gap_line is None:
        return None

    # Example:
    # :GAP (global)   :  0.084481 Ry =     1.149 eV
    # :GAP (this spin):  0.020982 Ry =     0.285 eV
    m = re.search(r"=\s*([-+]?\d*\.\d+|[-+]?\d+)\s*eV", gap_line)

    if m:
        return float(m.group(1))

    return None


def main():
    lines = []

    lines.append("# Band gaps")
    lines.append("")
    lines.append("| Band gap (eV) | Si | GaAs | InAs |")
    lines.append("|---|---:|---:|---:|")

    for label, dirname in RUNS:
        row = []

        for case in CASES:
            scf_file = Path(dirname) / case / case / f"{case}.scf"
            gap_ev = get_band_gap_ev(scf_file)

            if gap_ev is None:
                row.append("missing")
            else:
                row.append(f"{gap_ev:.3f}")

        lines.append(f"| {label} | {row[0]} | {row[1]} | {row[2]} |")

    text = "\n".join(lines) + "\n"

    print(text)

    with open(OUTPUT_FILE, "w") as f:
        f.write(text)

    print(f"Saved table to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
