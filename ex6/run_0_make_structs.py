#!/usr/bin/env python3

from ase.build import bulk
from ase.io import write

##### step 1: define lattice parameters in Angstrom #####
materials = {
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

##### step 2: generate WIEN2k struct files #####
for case, info in materials.items():

    print("")
    print("==========================================")
    print(f"Generating {case}.struct")
    print("==========================================")

    atoms = bulk(
        info["symbols"],
        crystalstructure=info["structure"],
        a=info["a"],
        cubic=True,
    )

    output_file = f"{case}.struct"

    write(output_file, atoms, format="struct")

    print(f"Wrote {output_file}")
    print(f"  structure = {info['structure']}")
    print(f"  a = {info['a']} Angstrom")
    print(f"  number of atoms = {len(atoms)}")
