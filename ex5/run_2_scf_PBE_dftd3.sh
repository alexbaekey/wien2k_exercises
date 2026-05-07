#!/usr/bin/env bash
set -e

CASE="bilayer_graphene"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

D_LIST="2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8"

##### step 1: recreate PBE+dftd3 directory #####
rm -rf "$BASE_DIR/2_scf_PBE_dftd3"
mkdir -p "$BASE_DIR/2_scf_PBE_dftd3"

##### step 2: loop over interlayer distances #####
for D in $D_LIST; do

    SRC_DIR="$BASE_DIR/1_scf_PBE/d_${D}/$CASE"
    RUN_DIR="$BASE_DIR/2_scf_PBE_dftd3/d_${D}/$CASE"

    echo ""
    echo "=========================================="
    echo "Running PBE+dftd3 for d = $D A"
    echo "=========================================="

    ##### step 3: check PBE calculation exists #####
    if [ ! -d "$SRC_DIR" ]; then
        echo "ERROR: missing $SRC_DIR"
        echo "Run ./run_1_scf_PBE.sh first."
        exit 1
    fi

    ##### step 4: copy converged PBE calculation #####
    mkdir -p "$BASE_DIR/2_scf_PBE_dftd3/d_${D}"
    cp -r "$SRC_DIR" "$RUN_DIR"

    ##### step 5: go into run directory #####
    cd "$RUN_DIR"

    ##### step 6: run SCF with dftd3 #####
    run_lapw -dftd3 -cc 0.00001 -ec 0.00001

    ##### step 7: print run info #####
    echo "total energy"
    grep ':ENE' "${CASE}.scf" | tail -1

    echo "Fermi energy"
    grep ':FER' "${CASE}.scf" | tail -1

done

##### step 8: collect energies #####
OUT="$BASE_DIR/2_scf_PBE_dftd3/energy_vs_d_PBE_dftd3.dat"
rm -f "$OUT"

for D in $D_LIST; do
    SCF="$BASE_DIR/2_scf_PBE_dftd3/d_${D}/$CASE/${CASE}.scf"
    ENE=$(grep ':ENE' "$SCF" | tail -1 | awk '{print $NF}')
    echo "$D $ENE" >> "$OUT"
done

echo ""
echo "Saved PBE+dftd3 energies to:"
echo "$OUT"
