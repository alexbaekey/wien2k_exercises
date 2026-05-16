#!/usr/bin/env python3
"""
Plot no-SOC WIEN2k fatbands from CASE.qtl and CASE.klist_band.

This version makes one clean orbital-character plot per material.

Instead of overlapping dots or variable-width lines, each band segment is drawn
with a constant linewidth and a color determined by the local s/p/d character.

Color convention:
    s -> blue
    p -> orange
    d -> green

Input layout:

    3_fatbands_noSOC/fatbands_output/Gr/Gr.qtl
    3_fatbands_noSOC/fatbands_output/Gr/Gr.klist_band

Output:

    4_fatband_plots_noSOC/Gr/Gr_fatband_spd_colorline.png
    4_fatband_plots_noSOC/hBN/hBN_fatband_spd_colorline.png
    4_fatband_plots_noSOC/MoSe2/MoSe2_fatband_spd_colorline.png
    4_fatband_plots_noSOC/WSe2/WSe2_fatband_spd_colorline.png

Run:

    python3 run_4_plot_fatbands_noSOC.py
"""

from pathlib import Path
import re
import shutil

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
from matplotlib.lines import Line2D


BASE_DIR = Path(__file__).resolve().parent

INPUT_BASE = BASE_DIR / "3_fatbands_noSOC" / "fatbands_output"
OUTPUT_BASE = BASE_DIR / "4_fatband_plots_noSOC"

CASE_LIST = ["Gr", "hBN", "MoSe2", "WSe2"]

RY_TO_EV = 13.605693122994

ENERGY_WINDOW_EV = (-8.0, 6.0)

#BAND_LINEWIDTH = 1.25
BAND_LINEWIDTH = 2
BACKGROUND_LINEWIDTH = 0.35

# RGB colors for orbital mixing.
S_COLOR = np.array([0.121, 0.466, 0.705])  # tab:blue
P_COLOR = np.array([1.000, 0.498, 0.054])  # tab:orange
D_COLOR = np.array([0.172, 0.627, 0.172])  # tab:green

GRAY_COLOR = np.array([0.35, 0.35, 0.35])


def parse_fermi_from_qtl(qtl_file):
    for line in qtl_file.read_text(errors="ignore").splitlines():
        if "FERMI ENERGY" in line.upper():
            nums = re.findall(
                r"[-+]?\d+\.\d+(?:[Ee][-+]?\d+)?|[-+]?\d+(?:[Ee][-+]?\d+)?",
                line,
            )
            if nums:
                return float(nums[-1])

    raise RuntimeError(f"Could not find FERMI ENERGY in {qtl_file}")


def parse_klist_labels(klist_file):
    label_positions = []
    label_names = []
    nk = 0

    for line in klist_file.read_text(errors="ignore").splitlines():
        if line.strip().upper().startswith("END"):
            break

        if not line.strip():
            continue

        label = line[:10].strip()

        if label:
            if label.upper() in ["GAMMA", "G"]:
                label = r"$\Gamma$"

            label_positions.append(nk)
            label_names.append(label)

        nk += 1

    return label_positions, label_names, nk


def normalize_label(label):
    label = label.strip().upper()

    mapping = {
        "0": "s",
        "1": "p",
        "2": "d",
    }

    return mapping.get(label, label.lower())


def parse_projection_labels(line):
    idx = line.lower().find("tot")

    if idx < 0:
        return None

    label_text = line[idx:]
    labels = [x.strip() for x in label_text.split(",") if x.strip()]

    if labels and labels[0].lower() == "tot":
        labels = labels[1:]

    return [normalize_label(x) for x in labels]


def numeric_values(line):
    try:
        return [float(x) for x in line.split()]
    except ValueError:
        return None


def parse_qtl(qtl_file, nk):
    """
    Parse WIEN2k qtl file by BAND blocks.

    Observed full-row format:

        energy  atom_or_mult_index  total  orbital_1  orbital_2 ...

    For header:

        tot,0,1,PZ,PX+PY,2,DZ2,DX2Y2+DXY,DXZ+DYZ,3

    we collect:
        0 -> s
        1 -> p
        2 -> d
    """

    lines = qtl_file.read_text(errors="ignore").splitlines()

    current_labels = None
    current_band = None
    current_k = 0

    band_data = {}

    for line in lines:
        stripped = line.strip()

        if not stripped:
            continue

        if stripped.upper().startswith("JATOM"):
            current_labels = parse_projection_labels(stripped)
            continue

        if stripped.upper().startswith("BAND"):
            parts = stripped.split()

            if len(parts) >= 2:
                current_band = int(parts[1])
                current_k = 0

                if current_band not in band_data:
                    band_data[current_band] = {
                        "energy": np.full(nk, np.nan),
                        "weights": {
                            "s": np.zeros(nk),
                            "p": np.zeros(nk),
                            "d": np.zeros(nk),
                        },
                    }

            continue

        nums = numeric_values(stripped)

        if nums is None:
            continue

        if current_band is None or current_labels is None:
            continue

        needed_cols = 3 + len(current_labels)

        # Ignore short equivalent-atom rows.
        if len(nums) < needed_cols:
            continue

        if current_k >= nk:
            continue

        energy_ry = nums[0]
        projection_values = nums[3:needed_cols]

        band_data[current_band]["energy"][current_k] = energy_ry

        for label, value in zip(current_labels, projection_values):
            if label in ["s", "p", "d"]:
                band_data[current_band]["weights"][label][current_k] += value

        current_k += 1

    if not band_data:
        raise RuntimeError(f"No band data parsed from {qtl_file}")

    complete_bands = []

    for band in sorted(band_data):
        if np.all(np.isfinite(band_data[band]["energy"])):
            complete_bands.append(band)

    if not complete_bands:
        raise RuntimeError(f"No complete bands found in {qtl_file}")

    nbands = len(complete_bands)

    energies_ry = np.zeros((nk, nbands))

    weights = {
        "s": np.zeros((nk, nbands)),
        "p": np.zeros((nk, nbands)),
        "d": np.zeros((nk, nbands)),
    }

    for ib, band in enumerate(complete_bands):
        energies_ry[:, ib] = band_data[band]["energy"]

        for orbital in ["s", "p", "d"]:
            weights[orbital][:, ib] = band_data[band]["weights"][orbital]

    return energies_ry, weights


def normalize_spd_at_each_point(weights):
    """
    Normalize s/p/d weights locally at each k-point and band.

    This makes the color show relative orbital character instead of absolute
    projection size.

    For each point:
        s_frac + p_frac + d_frac = 1

    If all weights are zero, assign gray.
    """

    s = np.array(weights["s"], dtype=float)
    p = np.array(weights["p"], dtype=float)
    d = np.array(weights["d"], dtype=float)

    s = np.nan_to_num(s, nan=0.0, posinf=0.0, neginf=0.0)
    p = np.nan_to_num(p, nan=0.0, posinf=0.0, neginf=0.0)
    d = np.nan_to_num(d, nan=0.0, posinf=0.0, neginf=0.0)

    s[s < 0.0] = 0.0
    p[p < 0.0] = 0.0
    d[d < 0.0] = 0.0

    total = s + p + d

    s_frac = np.zeros_like(s)
    p_frac = np.zeros_like(p)
    d_frac = np.zeros_like(d)

    mask = total > 1.0e-12

    s_frac[mask] = s[mask] / total[mask]
    p_frac[mask] = p[mask] / total[mask]
    d_frac[mask] = d[mask] / total[mask]

    return s_frac, p_frac, d_frac, mask


def make_segment_colors(s_frac, p_frac, d_frac, valid_mask):
    """
    Make one RGB color per line segment.

    Segment color is the average orbital character of its two endpoints.
    """

    s_seg = 0.5 * (s_frac[:-1] + s_frac[1:])
    p_seg = 0.5 * (p_frac[:-1] + p_frac[1:])
    d_seg = 0.5 * (d_frac[:-1] + d_frac[1:])

    valid_seg = valid_mask[:-1] | valid_mask[1:]

    colors = (
        s_seg[:, None] * S_COLOR[None, :]
        + p_seg[:, None] * P_COLOR[None, :]
        + d_seg[:, None] * D_COLOR[None, :]
    )

    colors[~valid_seg] = GRAY_COLOR

    return colors


def add_colorline(ax, x, y, colors):
    points = np.column_stack([x, y])
    segments = np.stack([points[:-1], points[1:]], axis=1)

    lc = LineCollection(
        segments,
        colors=colors,
        linewidths=BAND_LINEWIDTH,
        alpha=1.0,
        capstyle="round",
        joinstyle="round",
        zorder=2,
    )

    ax.add_collection(lc)


def plot_spd_colorline(case, energies_ev, weights, label_positions, label_names, output_file):
    nk, nbands = energies_ev.shape
    x = np.arange(nk)

    s_frac, p_frac, d_frac, valid_mask = normalize_spd_at_each_point(weights)

    fig, ax = plt.subplots(figsize=(7.6, 5.3))

    # Very light background bands help show weak/zero-character parts.
    for ib in range(nbands):
        ax.plot(
            x,
            energies_ev[:, ib],
            color="black",
            linewidth=BACKGROUND_LINEWIDTH,
            alpha=0.25,
            zorder=1,
        )

    # Main color-character bands.
    for ib in range(nbands):
        colors = make_segment_colors(
            s_frac=s_frac[:, ib],
            p_frac=p_frac[:, ib],
            d_frac=d_frac[:, ib],
            valid_mask=valid_mask[:, ib],
        )

        add_colorline(
            ax=ax,
            x=x,
            y=energies_ev[:, ib],
            colors=colors,
        )

    for xpos in label_positions:
        ax.axvline(xpos, color="black", linewidth=0.6, alpha=0.35, zorder=0)

    ax.axhline(0.0, color="black", linewidth=0.8, linestyle="--", alpha=0.65, zorder=0)

    if label_positions and label_names:
        ax.set_xticks(label_positions)
        ax.set_xticklabels(label_names)
    else:
        ax.set_xlabel("k-point index")

    ax.set_xlim(0, nk - 1)
    ax.set_ylim(*ENERGY_WINDOW_EV)
    ax.set_ylabel(r"$E - E_F$ (eV)")
    ax.set_title(f"{case} no-SOC orbital character: s / p / d")

    legend_handles = [
        Line2D([0], [0], color=S_COLOR, lw=3.0, label="s"),
        Line2D([0], [0], color=P_COLOR, lw=3.0, label="p"),
        Line2D([0], [0], color=D_COLOR, lw=3.0, label="d"),
        Line2D([0], [0], color=GRAY_COLOR, lw=3.0, label="weak / unassigned"),
    ]

    ax.legend(handles=legend_handles, loc="upper right", frameon=False, fontsize=9)

    fig.tight_layout()
    fig.savefig(output_file, dpi=300)
    plt.close(fig)

    print(f"Saved {output_file}")


def plot_case(case):
    case_dir = INPUT_BASE / case

    qtl_file = case_dir / f"{case}.qtl"
    klist_file = case_dir / f"{case}.klist_band"

    if not qtl_file.exists():
        raise FileNotFoundError(f"Missing {qtl_file}")

    if not klist_file.exists():
        raise FileNotFoundError(f"Missing {klist_file}")

    output_dir = OUTPUT_BASE
    output_dir.mkdir(parents=True, exist_ok=True)

    fermi_ry = parse_fermi_from_qtl(qtl_file)
    label_positions, label_names, nk = parse_klist_labels(klist_file)

    energies_ry, weights = parse_qtl(qtl_file, nk)
    energies_ev = (energies_ry - fermi_ry) * RY_TO_EV

    print("")
    print("=" * 70)
    print(case)
    print("=" * 70)
    print(f"Input: {case_dir}")
    print(f"Fermi energy: {fermi_ry:.8f} Ry")
    print(f"k-points from klist_band: {nk}")
    print(f"bands parsed: {energies_ev.shape[1]}")

    output_file = output_dir / f"{case}_fatband_spd_colorline.png"

    plot_spd_colorline(
        case=case,
        energies_ev=energies_ev,
        weights=weights,
        label_positions=label_positions,
        label_names=label_names,
        output_file=output_file,
    )


def main():
    if not INPUT_BASE.exists():
        raise FileNotFoundError(f"Missing input directory: {INPUT_BASE}")

    if OUTPUT_BASE.exists():
        shutil.rmtree(OUTPUT_BASE)

    OUTPUT_BASE.mkdir(parents=True, exist_ok=True)

    for case in CASE_LIST:
        plot_case(case)

    print("")
    print("All no-SOC orbital-character plots finished.")
    print(f"Output directory: {OUTPUT_BASE}")


if __name__ == "__main__":
    main()
