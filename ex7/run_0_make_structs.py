#!/usr/bin/env python3

import numpy as np
from ase import Atoms
from ase.io import write

##### step 1: define materials #####
materials = {
    "Gr": {
        "symbols": ["C", "C"],
        "a": 2.46,
        "d": 0.0,
        "kind": "honeycomb",
        "rmt": [1.25, 1.25],
    },
    "hBN": {
        "symbols": ["B", "N"],
        "a": 2.50,
        "d": 0.0,
        "kind": "honeycomb",
        "rmt": [1.25, 1.25],
    },
    "MoSe2": {
        "symbols": ["Mo", "Se", "Se"],
        "a": 3.28,
        "d": 3.34,
        "kind": "tmd",
        "rmt": [2.00, 1.85, 1.85],
    },
    "WSe2": {
        "symbols": ["W", "Se", "Se"],
        "a": 3.28,
        "d": 3.34,
        "kind": "tmd",
        "rmt": [2.00, 1.85, 1.85],
    },
}

vacuum = 16.0

##### step 2: loop over materials #####
for case, params in materials.items():

    ##### step 3: define cell height #####
    a = params["a"]
    d = params["d"]
    c = vacuum + d

    ##### step 4: define hexagonal in-plane cell #####
    cell = [
        [a, 0.0, 0.0],
        [0.5 * a, np.sqrt(3.0) * 0.5 * a, 0.0],
        [0.0, 0.0, c],
    ]

    ##### step 5: define atomic positions #####
    if params["kind"] == "honeycomb":

        ##### flat two-atom honeycomb layer centered in the cell #####
        scaled_positions = [
            [0.0,       0.0,       0.5],
            [1.0 / 3.0, 1.0 / 3.0, 0.5],
        ]

    elif params["kind"] == "tmd":

        ##### monolayer MX2 centered in the cell #####
        ##### d is the vertical Se-Se layer thickness #####
        z_metal = 0.5
        z_se_bottom = 0.5 - 0.5 * d / c
        z_se_top = 0.5 + 0.5 * d / c

        scaled_positions = [
            [0.0,       0.0,       z_metal],
            [1.0 / 3.0, 1.0 / 3.0, z_se_bottom],
            [2.0 / 3.0, 2.0 / 3.0, z_se_top],
        ]

    else:
        raise ValueError(f"Unknown structure kind: {params['kind']}")

    atoms = Atoms(
        symbols=params["symbols"],
        scaled_positions=scaled_positions,
        cell=cell,
        pbc=[True, True, True],
    )

    ##### step 6: write WIEN2k struct file #####
    filename = f"{case}.struct"

    write(
        filename,
        atoms,
        format="struct",
        rmt=params["rmt"],
    )

    print(f"Wrote {filename}")
    print(f"  a = {a:.6f} A")
    print(f"  d = {d:.6f} A")
    print(f"  vacuum = {vacuum:.6f} A")
    print(f"  total cell height c = {c:.6f} A")
    print(f"  RMT values = {params['rmt']}")
    print("")
