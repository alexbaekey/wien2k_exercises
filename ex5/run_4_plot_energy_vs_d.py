#!/usr/bin/env python3

import numpy as np
import matplotlib.pyplot as plt


##### step 1: define input files #####
DATASETS = [
    ("1_scf_PBE/energy_vs_d_PBE.dat", "PBE"),
    ("2_scf_PBE_dftd3/energy_vs_d_PBE_dftd3.dat", "PBE+dftd3"),
    ("3_scf_PBE_nlvdw/energy_vs_d_PBE_nlvdw.dat", "PBE+nlvdW"),
]


##### step 2: read energy data #####
def read_data(filename):
    data = np.loadtxt(filename)

    d = data[:, 0]
    e = data[:, 1]

    ##### sort by distance just in case #####
    idx = np.argsort(d)
    d = d[idx]
    e = e[idx]

    return d, e


##### step 3: do global quadratic fit #####
def quadratic_fit(d, e, label):
    ##### fit all data points to E(d) = a d^2 + b d + c #####
    p = np.polyfit(d, e, 2)
    a, b, c = p

    ##### dense grid for plotting fit #####
    d_fit = np.linspace(d.min(), d.max(), 1000)
    e_fit = np.polyval(p, d_fit)

    ##### print fit quality #####
    e_pred = np.polyval(p, d)
    ss_res = np.sum((e - e_pred) ** 2)
    ss_tot = np.sum((e - np.mean(e)) ** 2)

    if ss_tot > 0:
        r2 = 1.0 - ss_res / ss_tot
        print(f"{label}: quadratic fit R^2 = {r2:.6f}")

    print("")

    return d_fit, e_fit, p


##### step 4: plot one dataset #####
def plot_one(filename, label):
    d, e = read_data(filename)

    ##### shift each curve by its own calculated minimum #####
    e_min = np.min(e)
    e_shift = e - e_min

    ##### plot calculated points #####
    line, = plt.plot(
        d,
        e_shift,
        "o",
        linewidth=2,
        markersize=6,
        label=f"{label} calculated",
    )

    color = line.get_color()

    ##### global quadratic fit #####
    d_fit, e_fit, p = quadratic_fit(d, e, label)

    ##### shift fitted curve by same energy minimum #####
    e_fit_shift = e_fit - e_min

    ##### plot fitted curve across full sampled range #####
    plt.plot(
        d_fit,
        e_fit_shift,
        "--",
        color=color,
        linewidth=1.0,
        alpha=0.45,
        label=f"{label} quadratic fit",
    )

##### step 5: make plot #####
for filename, label in DATASETS:
    plot_one(filename, label)


##### step 6: decorate plot #####
plt.xlabel("Interlayer distance d (A)")
plt.ylabel("Energy - minimum energy (Ry)")
plt.title("Bilayer graphene interlayer distance")
plt.legend(fontsize=8)
plt.grid(True)


##### step 7: save figure #####
plt.tight_layout()
plt.savefig("energy_vs_d.png", dpi=300)

print("Saved plot to energy_vs_d.png")
