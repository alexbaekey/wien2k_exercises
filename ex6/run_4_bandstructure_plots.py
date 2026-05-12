#!/usr/bin/env python3

from pathlib import Path
import re

import numpy as np
import matplotlib.pyplot as plt


##### step 1: settings #####
MATERIALS = ["Si", "GaAs", "InAs"]
METHODS = ["PBE", "HSE"]

METHOD_COLORS = {
    "PBE": "black",
    "HSE": "red",
}

BASE_DIR = Path("5_bandstructures_SOC")

YMIN = -8.0
YMAX = 8.0

OUTPUT_COMBINED = "PBE_HSE_SOC_bandstructures.png"


##### step 2: helper functions #####
def extract_floats(line):
    return [
        float(x.replace("D", "E"))
        for x in re.findall(
            r"[-+]?\d*\.\d+(?:[EeDd][-+]?\d+)?|[-+]?\d+(?:[EeDd][-+]?\d+)?",
            line,
        )
    ]


def read_spaghetti_ene(filename):
    """
    Read WIEN2k spaghetti_ene file.

    Expected numeric rows look like:

        kx ky kz x_distance energy

    So we plot:
        x = second-to-last column
        y = last column
    """

    filename = Path(filename)

    if not filename.exists():
        raise FileNotFoundError(f"Missing file: {filename}")

    if filename.stat().st_size == 0:
        raise RuntimeError(f"Empty file: {filename}")

    bands = []
    current_x = []
    current_e = []

    with open(filename, "r", errors="ignore") as f:
        for line in f:
            line_strip = line.strip()

            ##### new band block #####
            if line_strip.lower().startswith("bandindex"):
                if len(current_x) > 0:
                    bands.append((np.array(current_x), np.array(current_e)))
                    current_x = []
                    current_e = []
                continue

            nums = extract_floats(line)

            ##### numeric band line: kx ky kz x energy #####
            if len(nums) >= 5:
                x = nums[-2]
                e = nums[-1]

                current_x.append(x)
                current_e.append(e)

    if len(current_x) > 0:
        bands.append((np.array(current_x), np.array(current_e)))

    ##### remove empty or tiny bands #####
    bands = [(x, e) for x, e in bands if len(x) > 2]

    if len(bands) == 0:
        raise RuntimeError(f"No bands found in {filename}")

    print(f"Read {len(bands)} bands from {filename}")

    return bands


def get_spaghetti_file(material, method):
    filename = BASE_DIR / material / "results" / f"{material}_{method}_SOC.spaghetti_ene"

    if not filename.exists():
        raise FileNotFoundError(f"Missing spaghetti_ene file: {filename}")

    return filename


def get_x_ticks_from_bands(bands):
    """
    For X-GAMMA-K with 100 points per segment, the middle point is GAMMA.
    """

    x = bands[0][0]

    x_start = x[0]
    x_end = x[-1]

    ##### find the point closest to the middle of the path #####
    x_mid_target = 0.5 * (x_start + x_end)
    i_mid = np.argmin(np.abs(x - x_mid_target))
    x_mid = x[i_mid]

    return [x_start, x_mid, x_end], ["X", r"$\Gamma$", "K"]


##### step 3: plot one material with PBE and HSE overlaid #####
def plot_material(ax, material):
    for method in METHODS:
        spaghetti_file = get_spaghetti_file(material, method)
        bands = read_spaghetti_ene(spaghetti_file)

        color = METHOD_COLORS[method]

        ##### label only first band to avoid huge legend #####
        first = True

        for x, e in bands:
            if first:
                ax.plot(
                    x,
                    e,
                    linewidth=0.8,
                    color=color,
                    label=method,
                )
                first = False
            else:
                ax.plot(
                    x,
                    e,
                    linewidth=0.8,
                    color=color,
                )

    ##### ticks from PBE file #####
    pbe_bands = read_spaghetti_ene(get_spaghetti_file(material, "PBE"))
    xticks, labels = get_x_ticks_from_bands(pbe_bands)

    for xpos in xticks:
        ax.axvline(xpos, linestyle="--", linewidth=0.7, alpha=0.6)

    ax.axhline(0.0, linestyle="--", linewidth=0.8, alpha=0.8)

    ax.set_xlim(xticks[0], xticks[-1])
    ax.set_ylim(YMIN, YMAX)

    ax.set_xticks(xticks)
    ax.set_xticklabels(labels)

    ax.set_title(f"{material} PBE vs HSE + SOC")
    ax.set_ylabel("Energy (eV)")
    ax.set_xlabel("k-path")
    ax.grid(True, alpha=0.25)
    ax.legend()


##### step 4: combined plot #####
fig, axes = plt.subplots(1, 3, figsize=(15, 4), sharey=True)

for ax, material in zip(axes, MATERIALS):
    plot_material(ax, material)

plt.tight_layout()
plt.savefig(OUTPUT_COMBINED, dpi=300)
plt.close(fig)

print("")
print(f"Saved combined plot to {OUTPUT_COMBINED}")


##### step 5: individual plots #####
for material in MATERIALS:
    fig, ax = plt.subplots(figsize=(5, 4))

    plot_material(ax, material)

    outname = f"{material}_PBE_HSE_SOC_bandstructure.png"

    plt.tight_layout()
    plt.savefig(outname, dpi=300)
    plt.close(fig)

    print(f"Saved {outname}")
