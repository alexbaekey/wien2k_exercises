#!/usr/bin/env python3
"""
Extract electron counts inside MT spheres and in the interstitial region
from converged no-SOC WIEN2k .scf files.

Uses:
    total electrons = :NOE
    interstitial electrons = final interstitial charge line
    MT-sphere electrons = total electrons - interstitial electrons

Expected input files:
    1_PBE_noSOC/Gr/Gr.scf
    1_PBE_noSOC/hBN/hBN.scf
    1_PBE_noSOC/MoSe2/MoSe2.scf
    1_PBE_noSOC/WSe2/WSe2.scf

Output:
    run_2_noSOC_charge_summary.md
"""

from pathlib import Path
import re


BASE_DIR = Path(__file__).resolve().parent
CASE_LIST = ["Gr", "hBN", "MoSe2", "WSe2"]


def last_float(line):
    nums = re.findall(
        r"[-+]?\d+\.\d+(?:[Ee][-+]?\d+)?|[-+]?\d+(?:[Ee][-+]?\d+)?",
        line,
    )
    if not nums:
        return None
    return float(nums[-1])


def extract_charge_info(case):
    scf_file = BASE_DIR / "1_PBE_noSOC" / case / f"{case}.scf"

    result = {
        "case": case,
        "scf_file": scf_file,
        "total": None,
        "interstitial": None,
        "mt_total": None,
    }


    lines = scf_file.read_text(errors="ignore").splitlines()

    for line in lines:
        upper = line.upper()

        if ":NOE" in upper:
            value = last_float(line)
            if value is not None:
                result["total"] = value

        if "INTERSTITIAL" in upper and "CHARGE" in upper:
            value = last_float(line)
            if value is not None:
                result["interstitial"] = value

    if result["total"] is not None and result["interstitial"] is not None:
        result["mt_total"] = result["total"] - result["interstitial"]
    else:
        print("could not find total and/or interstitial charge")

    return result


def fmt(value):
    if value is None:
        return "not found"
    return f"{value:.6f}"


def main():
    results = [extract_charge_info(case) for case in CASE_LIST]

    output_file = BASE_DIR / "run_2_noSOC_charge_summary.md"

    with output_file.open("w") as f:
        f.write("# no-SOC MT-sphere and interstitial electron counts\n\n")
        f.write(
            "Settings: PBE, ECUT = -6.0 Ry, RKMAX = 7, "
            "15 x 15 x 1 k-mesh, cc/ec = 1e-5.\n\n"
        )

        f.write(
            "| Case | Electrons inside MT spheres | "
            "Electrons in interstitial | Total electrons from :NOE | Status |\n"
        )
        f.write("|---|---:|---:|---|\n")

        for r in results:
            f.write(
                f"| {r['case']} "
                f"| {fmt(r['mt_total'])} "
                f"| {fmt(r['interstitial'])} "
                f"| {fmt(r['total'])} \n"
            )

    print(output_file.read_text())
    print(f"Saved summary to: {output_file}")


if __name__ == "__main__":
    main()
