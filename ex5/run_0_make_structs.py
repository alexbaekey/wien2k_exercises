import numpy as np
from ase import Atoms
from ase.io import write

CASE = "bilayer_graphene"

##### step 1: define geometry #####
cc = 1.42
a = np.sqrt(3.0) * cc

vacuum_each_side = 8.0
total_vacuum = 2.0 * vacuum_each_side

d_list = [2.8, 2.9, 3.0, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8]

##### step 2: loop over interlayer distances #####
for d in d_list:

    ##### step 3: define total cell height #####
    c = d + total_vacuum

    ##### step 4: define hexagonal in-plane cell #####
    cell = [
        [a, 0.0, 0.0],
        [0.5 * a, np.sqrt(3.0) * 0.5 * a, 0.0],
        [0.0, 0.0, c],
    ]

    ##### step 5: define z positions #####
    ##### This gives 8 A vacuum below the lower layer
    ##### and 8 A vacuum above the upper layer.
    z_lower = vacuum_each_side
    z_upper = vacuum_each_side + d

    ##### step 6: define Bernal AB stacking #####
    ##### Bottom layer: A1, B1
    ##### Top layer:    A2 above B1, B2 shifted
    scaled_positions = [
        [0.0,       0.0,       z_lower / c],
        [1.0 / 3.0, 1.0 / 3.0, z_lower / c],
        [1.0 / 3.0, 1.0 / 3.0, z_upper / c],
        [2.0 / 3.0, 2.0 / 3.0, z_upper / c],
    ]

    atoms = Atoms(
        symbols=["C", "C", "C", "C"],
        scaled_positions=scaled_positions,
        cell=cell,
        pbc=[True, True, True],
    )

    ##### step 7: write WIEN2k struct file #####
    tag = str(d).replace(".", "p")
    filename = f"{CASE}_d_{tag}.struct"

    write(filename, atoms, format="struct")

    print(f"Wrote {filename}")
    print(f"  in-plane C-C distance = {cc:.4f} A")
    print(f"  lattice a = {a:.6f} A")
    print(f"  interlayer distance d = {d:.6f} A")
    print(f"  vacuum below bilayer = {vacuum_each_side:.6f} A")
    print(f"  vacuum above bilayer = {vacuum_each_side:.6f} A")
    print(f"  total cell height c = {c:.6f} A")
    print("")
