#!/usr/bin/env python3

# run with 
# mpirun -np 12 python run.py
# for 12 cores

# Note that the time comparisons for SOC runs are not 1 to 1, GPAW is not using SCF, it uses "non-self-consistent SOC on top of a converged scalar-relativistic calculation" according to chatgpt, check this in gpaw docs

from pathlib import Path
import time
import json

import numpy as np
import matplotlib.pyplot as plt

from ase.build import bulk
from gpaw import GPAW, PW, FermiDirac
from gpaw.spinorbit import soc_eigenstates


##### step 1: user settings #####

MATERIALS = {
    "Si": {
        "symbols": "Si",
        "structure": "diamond",
        "a": 5.4124,
    },
    "GaAs": {
        "symbols": "GaAs",
        "structure": "zincblende",
        "a": 5.6533,
    },
    "InAs": {
        "symbols": "InAs",
        "structure": "zincblende",
        "a": 6.0583,
    },
}

METHODS = {
    "PBE": "PBE",
    "HSE": "HSE06",
}

BASE_DIR = Path("gpaw_ex6")

#KPTS_SCF = (5, 5, 5)
KPTS_SCF = (4, 4, 4)

##### GPAW uses eV plane-wave cutoff, not WIEN2k RKMAX #####
PW_ECUT = 400

##### number of bands for SCF and band plots #####
NBANDS_SCF = {
    "Si": 16,
    "GaAs": 32,
    "InAs": 40,
}

NBANDS_BAND = {
    "Si": 6,
    "GaAs": 16,
    "InAs": 19,
}

##### X-GAMMA-K path matching your XCrySDen/WIEN2k-style fractional coordinates #####
SPECIAL_POINTS = {
    "X": [0.0, 0.5, 0.5],
    "G": [0.0, 0.0, 0.0],
    "K": [0.375, 0.375, 0.75],
}

BAND_PATH = "XGK"

BAND_NPOINTS = 100

YMIN = -8.0
YMAX = 8.0

FERMI_WIDTH = 0.01

REUSE_EXISTING_GPW = True


##### step 2: small helpers #####

def make_atoms(material):
    info = MATERIALS[material]

    atoms = bulk(
        info["symbols"],
        crystalstructure=info["structure"],
        a=info["a"],
        cubic=True,
    )

    return atoms


def ensure_dir(path):
    path = Path(path)
    path.mkdir(parents=True, exist_ok=True)
    return path


def timed_run(label, func):
    print("")
    print("==========================================")
    print(label)
    print("==========================================")

    t0 = time.perf_counter()
    result = func()
    t1 = time.perf_counter()

    minutes = (t1 - t0) / 60.0

    print(f"{label} finished in {minutes:.2f} minutes")

    return result, minutes


def collect_eigenvalues(calc):
    eigs = []

    nspins = calc.get_number_of_spins()
    nkpts = len(calc.get_ibz_k_points())

    for spin in range(nspins):
        for kpt in range(nkpts):
            eigs.extend(calc.get_eigenvalues(kpt=kpt, spin=spin))

    return np.array(eigs)


def gap_from_calc(calc):
    """
    Simple gap estimate from eigenvalues around the Fermi level.

    This is analogous to using the final SCF eigenvalues to find
    the highest state below EF and the lowest state above EF.
    """

    ef = calc.get_fermi_level()
    eigs = collect_eigenvalues(calc)

    below = eigs[eigs <= ef]
    above = eigs[eigs > ef]

    if len(below) == 0 or len(above) == 0:
        return 0.0

    vbm = np.max(below)
    cbm = np.min(above)

    gap = cbm - vbm

    if gap < 0:
        gap = 0.0

    return gap


def gap_from_band_eigs(e_kn, ef):
    eigs = np.ravel(e_kn)

    below = eigs[eigs <= ef]
    above = eigs[eigs > ef]

    if len(below) == 0 or len(above) == 0:
        return 0.0

    vbm = np.max(below)
    cbm = np.min(above)

    gap = cbm - vbm

    if gap < 0:
        gap = 0.0

    return gap


##### step 3: SCF calculations #####

def run_scf(material, method_label):
    atoms = make_atoms(material)
    xc = METHODS[method_label]

    run_dir = ensure_dir(BASE_DIR / f"{method_label}_noSOC" / material)
    gpw_file = run_dir / f"{material}_{method_label}_noSOC.gpw"
    txt_file = run_dir / f"{material}_{method_label}_noSOC.txt"

    if REUSE_EXISTING_GPW and gpw_file.exists():
        print(f"Reusing existing {gpw_file}")
        calc = GPAW(str(gpw_file), txt=None)
        energy = atoms.get_potential_energy() if atoms.calc is not None else None
        gap = gap_from_calc(calc)
        return gpw_file, gap

    calc = GPAW(
        mode=PW(PW_ECUT),
        xc=xc,
        kpts=KPTS_SCF,
        nbands=NBANDS_SCF[material],
        occupations=FermiDirac(FERMI_WIDTH),
        txt=str(txt_file),
    )

    atoms.calc = calc
    energy = atoms.get_potential_energy()

    calc.write(str(gpw_file), mode="all")

    gap = gap_from_calc(calc)

    with open(run_dir / "summary.txt", "w") as f:
        f.write(f"material = {material}\n")
        f.write(f"method = {method_label}\n")
        f.write(f"xc = {xc}\n")
        f.write(f"energy_eV = {energy:.12f}\n")
        f.write(f"fermi_eV = {calc.get_fermi_level():.12f}\n")
        f.write(f"gap_eV = {gap:.6f}\n")

    return gpw_file, gap


##### step 4: band structure and SOC calculations #####

def run_band_and_soc(material, method_label, gpw_file):
    atoms = make_atoms(material)

    band_dir = ensure_dir(BASE_DIR / "bandstructures" / material / method_label)

    bp = atoms.cell.bandpath(
        BAND_PATH,
        special_points=SPECIAL_POINTS,
        npoints=BAND_NPOINTS,
    )

    nbands = NBANDS_BAND[material]

    def do_band():
        calc = GPAW(str(gpw_file), txt=None)

        band_calc = calc.fixed_density(
            nbands=nbands,
            symmetry="off",
            kpts=bp,
            convergence={"bands": nbands},
            txt=str(band_dir / f"{material}_{method_label}_band.txt"),
        )

        ##### force eigenvalue calculation #####
        band_calc.get_potential_energy()

        ef = calc.get_fermi_level()

        ##### noSOC band eigenvalues #####
        e_kn = []
        for ik in range(len(bp.kpts)):
            e_kn.append(band_calc.get_eigenvalues(kpt=ik, spin=0)[:nbands])
        e_kn = np.array(e_kn)

        ##### SOC eigenvalues from scalar-relativistic band calculation #####
        soc = soc_eigenstates(band_calc, n1=0, n2=nbands)
        e_soc_kn = soc.eigenvalues()

        ##### x-axis from ASE bandpath #####
        x, x_ticks, labels = bp.get_linear_kpoint_axis()
        labels = [lab.replace("G", r"$\Gamma$") for lab in labels]

        np.savez(
            band_dir / f"{material}_{method_label}_bands.npz",
            x=x,
            x_ticks=np.array(x_ticks),
            labels=np.array(labels),
            e_nosoc_kn=e_kn,
            e_soc_kn=e_soc_kn,
            ef=ef,
        )

        gap_soc = gap_from_band_eigs(e_soc_kn, ef)

        with open(band_dir / "summary.txt", "w") as f:
            f.write(f"material = {material}\n")
            f.write(f"method = {method_label}\n")
            f.write(f"fermi_eV = {ef:.12f}\n")
            f.write(f"soc_band_gap_eV = {gap_soc:.6f}\n")

        return gap_soc

    gap_soc, minutes = timed_run(
        f"{material} {method_label} SOC band/postprocessing",
        do_band,
    )

    return gap_soc, minutes


##### step 5: plotting #####

def load_band_npz(material, method_label):
    filename = BASE_DIR / "bandstructures" / material / method_label / f"{material}_{method_label}_bands.npz"

    if not filename.exists():
        raise FileNotFoundError(f"Missing band file: {filename}")

    return np.load(filename, allow_pickle=True)


def plot_one_material(material):
    fig, ax = plt.subplots(figsize=(5, 4))

    colors = {
        "PBE": "black",
        "HSE": "red",
    }

    for method_label in ["PBE", "HSE"]:
        data = load_band_npz(material, method_label)

        x = data["x"]
        e_soc_kn = data["e_soc_kn"]
        ef = float(data["ef"])

        e_plot = e_soc_kn - ef

        label = method_label

        for ib in range(e_plot.shape[1]):
            ax.plot(
                x,
                e_plot[:, ib],
                color=colors[method_label],
                linewidth=0.8,
                label=label,
            )
            label = None

    data = load_band_npz(material, "PBE")

    x_ticks = data["x_ticks"]
    labels = list(data["labels"])

    for xpos in x_ticks:
        ax.axvline(xpos, linestyle="--", linewidth=0.7, alpha=0.6)

    ax.axhline(0.0, linestyle="--", linewidth=0.8, alpha=0.8)

    ax.set_xticks(x_ticks)
    ax.set_xticklabels(labels)

    ax.set_xlim(x_ticks[0], x_ticks[-1])
    ax.set_ylim(YMIN, YMAX)

    ax.set_title(f"{material} PBE vs HSE + SOC")
    ax.set_xlabel("k-path")
    ax.set_ylabel(r"$E - E_F$ (eV)")
    ax.grid(True, alpha=0.25)
    ax.legend()

    out = BASE_DIR / f"{material}_PBE_HSE_SOC_bandstructure.png"
    plt.tight_layout()
    plt.savefig(out, dpi=300)
    plt.close(fig)

    print(f"Saved {out}")


def plot_combined():
    fig, axes = plt.subplots(1, 3, figsize=(15, 4), sharey=True)

    colors = {
        "PBE": "black",
        "HSE": "red",
    }

    for ax, material in zip(axes, ["Si", "GaAs", "InAs"]):
        for method_label in ["PBE", "HSE"]:
            data = load_band_npz(material, method_label)

            x = data["x"]
            e_soc_kn = data["e_soc_kn"]
            ef = float(data["ef"])

            e_plot = e_soc_kn - ef

            label = method_label

            for ib in range(e_plot.shape[1]):
                ax.plot(
                    x,
                    e_plot[:, ib],
                    color=colors[method_label],
                    linewidth=0.8,
                    label=label,
                )
                label = None

        data = load_band_npz(material, "PBE")

        x_ticks = data["x_ticks"]
        labels = list(data["labels"])

        for xpos in x_ticks:
            ax.axvline(xpos, linestyle="--", linewidth=0.7, alpha=0.6)

        ax.axhline(0.0, linestyle="--", linewidth=0.8, alpha=0.8)

        ax.set_xticks(x_ticks)
        ax.set_xticklabels(labels)

        ax.set_xlim(x_ticks[0], x_ticks[-1])
        ax.set_ylim(YMIN, YMAX)

        ax.set_title(f"{material}")
        ax.set_xlabel("k-path")
        ax.grid(True, alpha=0.25)
        ax.legend()

    axes[0].set_ylabel(r"$E - E_F$ (eV)")

    out = BASE_DIR / "PBE_HSE_SOC_bandstructures.png"
    plt.tight_layout()
    plt.savefig(out, dpi=300)
    plt.close(fig)

    print(f"Saved {out}")


##### step 6: markdown tables #####

def write_runtimes_md(runtime_data):
    lines = []

    lines.append("# GPAW SCF runtimes")
    lines.append("")
    lines.append("| SCF time (minutes) | Si | GaAs | InAs |")
    lines.append("|---|---:|---:|---:|")

    rows = [
        ("PBE noSOC", "PBE_noSOC"),
        ("PBE withSOC", "PBE_withSOC"),
        ("HSE noSOC", "HSE_noSOC"),
        ("HSE withSOC", "HSE_withSOC"),
    ]

    for label, key in rows:
        row = []

        for material in ["Si", "GaAs", "InAs"]:
            value = runtime_data.get(material, {}).get(key, None)

            if value is None:
                row.append("missing")
            else:
                row.append(f"{value:.2f}")

        lines.append(f"| {label} | {row[0]} | {row[1]} | {row[2]} |")

    text = "\n".join(lines) + "\n"

    out = BASE_DIR / "runtimes.md"
    out.write_text(text)

    print("")
    print(text)
    print(f"Saved {out}")


def write_band_gaps_md(gap_data):
    lines = []

    lines.append("# GPAW band gaps")
    lines.append("")
    lines.append("| Band gap (eV) | Si | GaAs | InAs |")
    lines.append("|---|---:|---:|---:|")

    rows = [
        ("PBE noSOC", "PBE_noSOC"),
        ("PBE withSOC", "PBE_withSOC"),
        ("HSE noSOC", "HSE_noSOC"),
        ("HSE withSOC", "HSE_withSOC"),
    ]

    for label, key in rows:
        row = []

        for material in ["Si", "GaAs", "InAs"]:
            value = gap_data.get(material, {}).get(key, None)

            if value is None:
                row.append("missing")
            else:
                row.append(f"{value:.3f}")

        lines.append(f"| {label} | {row[0]} | {row[1]} | {row[2]} |")

    text = "\n".join(lines) + "\n"

    out = BASE_DIR / "band_gaps.md"
    out.write_text(text)

    print("")
    print(text)
    print(f"Saved {out}")


##### step 7: main workflow #####

def main():
    ensure_dir(BASE_DIR)

    runtime_data = {}
    gap_data = {}
    gpw_files = {}

    ##### SCF runs #####
    for material in ["Si", "GaAs", "InAs"]:
        runtime_data[material] = {}
        gap_data[material] = {}
        gpw_files[material] = {}

        for method_label in ["PBE", "HSE"]:
            label = f"{material} {method_label} noSOC SCF"

            def do_scf(material=material, method_label=method_label):
                return run_scf(material, method_label)

            (gpw_file, gap), minutes = timed_run(label, do_scf)

            gpw_files[material][method_label] = gpw_file

            runtime_data[material][f"{method_label}_noSOC"] = minutes
            gap_data[material][f"{method_label}_noSOC"] = gap

    ##### SOC band/postprocessing runs #####
    for material in ["Si", "GaAs", "InAs"]:
        for method_label in ["PBE", "HSE"]:
            gpw_file = gpw_files[material][method_label]

            gap_soc, minutes = run_band_and_soc(material, method_label, gpw_file)

            runtime_data[material][f"{method_label}_withSOC"] = minutes
            gap_data[material][f"{method_label}_withSOC"] = gap_soc

    ##### save json too #####
    with open(BASE_DIR / "results.json", "w") as f:
        json.dump(
            {
                "runtimes_minutes": runtime_data,
                "band_gaps_eV": gap_data,
            },
            f,
            indent=2,
        )

    ##### tables #####
    write_runtimes_md(runtime_data)
    write_band_gaps_md(gap_data)

    ##### plots #####
    for material in ["Si", "GaAs", "InAs"]:
        plot_one_material(material)

    plot_combined()

    print("")
    print("Finished GPAW reproduction.")
    print(f"Results are in: {BASE_DIR}")


if __name__ == "__main__":
    main()
