#!/usr/bin/env python3

from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt


##### user settings #####
CASE = "TiC"

BAND_DIR = Path("2_bandstructure") / CASE

OUT_DIR = Path("outputs")
OUT_DIR.mkdir(exist_ok=True)

YMIN = -10.0
YMAX = 10.0


##### energy settings #####
# WIEN2k qtl energies are usually in Ry.
# This subtracts EF and converts to eV.
CONVERT_RY_TO_EV = True
SUBTRACT_EF = True

RY_TO_EV = 13.605693122994


##### helper functions #####
def gamma_label(label):
    if label.upper() in ["GAMMA", "G"]:
        return r"$\Gamma$"
    return label


def read_fermi_energy(scf_file):
    ef = None

    with open(scf_file) as f:
        for line in f:
            if ":FER" in line:
                ef = float(line.split()[-1])

    if ef is None:
        raise RuntimeError(f"Could not find :FER in {scf_file}")

    return ef


def read_klist_band(klist_file):
    """
    Read k-points and high-symmetry labels from case.klist_band.

    Expected WIEN2k/XCrySDen style fixed-column format:

        label      kx        ky        kz        denom   weight
    """

    kpts = []
    label_indices = []
    labels = []

    with open(klist_file) as f:
        for line in f:
            if line.strip().startswith("END"):
                break

            label = line[:10].strip()

            try:
                kx = int(line[10:20])
                ky = int(line[20:30])
                kz = int(line[30:40])
                den = int(line[40:50])
            except ValueError:
                continue

            kpts.append([kx / den, ky / den, kz / den])

            if label != "":
                label_indices.append(len(kpts) - 1)
                labels.append(label)

    kpts = np.array(kpts, dtype=float)

    if len(kpts) == 0:
        raise RuntimeError(f"No k-points found in {klist_file}")

    # Cumulative distance in fractional reciprocal coordinates.
    dk = np.linalg.norm(np.diff(kpts, axis=0), axis=1)

    x = np.zeros(len(kpts))
    x[1:] = np.cumsum(dk)

    x_special = [x[i] for i in label_indices]

    return x, x_special, labels, kpts


def read_qtl_energies(qtl_file, nk):
    """
    Read WIEN2k case.qtl energies.

    The useful qtl rows usually look like:

        energy   atom_index   projections...

    The same eigenvalue is repeated for atom/projector rows.
    This keeps only rows where the second column is 1.

    For this TiC tutorial style qtl file, the flat order is usually:

        band 1, all k-points
        band 2, all k-points
        band 3, all k-points
        ...

    Therefore reshape as:

        (nbands, nk).T

    Returns:
        energies with shape nkpoints x nbands
    """

    energies_flat = []

    with open(qtl_file) as f:
        for line in f:
            parts = line.replace("D", "E").split()

            if len(parts) < 2:
                continue

            try:
                energy = float(parts[0])
                atom_index = int(parts[1])
            except ValueError:
                continue

            # Keep only the first repeated atom/projector row.
            if atom_index == 1:
                energies_flat.append(energy)

    if len(energies_flat) == 0:
        raise RuntimeError(f"No qtl energy rows found in {qtl_file}")

    nvals = len(energies_flat)

    if nvals % nk != 0:
        raise RuntimeError(
            f"Could not reshape qtl energies from {qtl_file}\n"
            f"Found {nvals} energy values, but nk={nk} k-points.\n"
            f"{nvals} is not divisible by {nk}."
        )

    nbands = nvals // nk

    print(f"{qtl_file}: found {nvals} energy values")
    print(f"{qtl_file}: nk={nk}, nbands={nbands}")

    energies = np.array(energies_flat, dtype=float).reshape(nbands, nk).T

    return energies


def apply_energy_settings(energies, ef):
    """
    Apply optional EF subtraction and Ry-to-eV conversion.
    """

    e = energies.copy()

    if SUBTRACT_EF:
        e = e - ef

    if CONVERT_RY_TO_EV:
        e = e * RY_TO_EV

    print(f"Plotted energy range: {np.nanmin(e):.4f} to {np.nanmax(e):.4f} eV")

    return e


def plot_bands():
    ##### step 1: read k-path #####
    klist_file = BAND_DIR / f"{CASE}.klist_band"
    x, x_special, labels, kpts = read_klist_band(klist_file)
    nk = len(x)

    print("Number of k-points:", nk)
    print("High-symmetry labels:", labels)

    ##### step 2: read Fermi energy #####
    scf_file = BAND_DIR / f"{CASE}.scf"
    ef = read_fermi_energy(scf_file)

    print("EF:", ef)
    print("Energy settings:")
    print("  SUBTRACT_EF =", SUBTRACT_EF)
    print("  CONVERT_RY_TO_EV =", CONVERT_RY_TO_EV)

    ##### step 3: read qtl energies #####
    qtl_file = BAND_DIR / f"{CASE}.qtl"
    e_raw = read_qtl_energies(qtl_file, nk)

    print("Raw energies shape:", e_raw.shape)

    ##### step 4: apply optional conversion/EF shift #####
    energies = apply_energy_settings(e_raw, ef)

    ##### step 5: plot #####
    fig, ax = plt.subplots(figsize=(8, 6))

    for ib in range(energies.shape[1]):
        ax.plot(
            x,
            energies[:, ib],
            linestyle="-",
            linewidth=1.0,
            color="black",
            alpha=0.9,
        )

    ##### step 6: high-symmetry vertical lines #####
    for xs in x_special:
        ax.axvline(xs, color="0.75", linewidth=0.8)

    ax.axhline(0.0, color="0.4", linewidth=0.8)

    ax.set_xlim(x[0], x[-1])
    ax.set_ylim(YMIN, YMAX)

    ax.set_ylabel(r"Energy - $E_F$ (eV)")
    ax.set_xticks(x_special)
    ax.set_xticklabels([gamma_label(lab) for lab in labels])

    ax.set_title("TiC band structure")

    plt.tight_layout()

    ##### step 7: save #####
    out_png = OUT_DIR / f"{CASE}_bandstructure_qtl.png"
    out_pdf = OUT_DIR / f"{CASE}_bandstructure_qtl.pdf"

    plt.savefig(out_png, dpi=300)
    plt.savefig(out_pdf)
    plt.close()

    print("Saved:", out_png)
    #print("Saved:", out_pdf)


if __name__ == "__main__":
    plot_bands()
