#!/usr/bin/env bash
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

CASE_LIST="Gr hBN MoSe2 WSe2"

##### calculation parameters #####
ECUT="-6.0"       # core/valence separation energy
RKMAX="7.0"
CC="0.00001"
EC="0.00001"

##### step 1: check .machines file #####
if [ ! -f "$BASE_DIR/.machines" ]; then
    echo "ERROR: missing $BASE_DIR/.machines"
    echo "Create a .machines file in the top directory before running this script."
    exit 1
fi

##### step 2: recreate calculation directory #####
rm -rf "$BASE_DIR/1_PBE_noSOC"
mkdir -p "$BASE_DIR/1_PBE_noSOC"

##### step 3: loop over materials #####
for CASE in $CASE_LIST; do

    STRUCT_FILE="$BASE_DIR/$CASE.struct"
    NOSOC_DIR="$BASE_DIR/1_PBE_noSOC/$CASE"

    echo ""
    echo "=========================================="
    echo "Running PBE noSOC for $CASE"
    echo "=========================================="

    ##### step 4: check struct file #####
    if [ ! -f "$STRUCT_FILE" ]; then
        echo "ERROR: missing $STRUCT_FILE"
        echo "Run python3 run_0_make_structs.py first."
        exit 1
    fi

    ##### step 5: make calculation directory #####
    mkdir -p "$NOSOC_DIR"

    ##### step 6: copy struct and .machines files #####
    cp "$STRUCT_FILE" "$NOSOC_DIR/$CASE.struct"
    cp "$BASE_DIR/.machines" "$NOSOC_DIR/.machines"

    ##### step 7: go into calculation directory #####
    cd "$NOSOC_DIR"

    ##### step 8: run sgroup #####
    x sgroup

    ##### step 9: replace struct with sgroup struct if created #####
    if [ -f "$CASE.struct_sgroup" ]; then
        cp "$CASE.struct" "$CASE.struct_before_sgroup"
        cp "$CASE.struct_sgroup" "$CASE.struct"
    else
        echo "WARNING: $CASE.struct_sgroup was not created"
    fi

    ##### step 10: initialize PBE noSOC calculation #####
    init_lapw -b -ecut "$ECUT" -rkmax "$RKMAX" -numk 225

    ##### step 11: overwrite k-mesh with exact 15 x 15 x 1 grid #####
    ##### Important: do not include an extra final 0 here.
    ##### The first 0 tells kgen to use manual divisions.
    printf "0\n15 15 1\n" | x kgen

    echo ""
    echo "kgen result for $CASE noSOC:"
    grep -i "k-points generated" "$CASE.outputkgen" || true
    grep -i "ndiv" "$CASE.outputkgen" || true
    echo ""

    ##### step 12: run noSOC SCF #####
    run_lapw -p -cc "$CC" -ec "$EC"

    ##### step 13: print noSOC info #####
    echo ""
    echo "PBE noSOC results for $CASE"

    echo "total energy"
    grep ':ENE' "$CASE.scf" | tail -1 || true

    echo "Fermi energy"
    grep ':FER' "$CASE.scf" | tail -1 || true

    echo "number of occupied bands"
    grep ':BAN' "$CASE.scf" | tail -1 || true

    echo "band gap"
    grep ':GAP' "$CASE.scf" | tail -1 || true

    ##### step 14: save noSOC summary #####
    {
        echo "$CASE PBE noSOC"
        echo ""
        echo "total energy"
        grep ':ENE' "$CASE.scf" | tail -1 || true
        echo ""
        echo "Fermi energy"
        grep ':FER' "$CASE.scf" | tail -1 || true
        echo ""
        echo "number of occupied bands"
        grep ':BAN' "$CASE.scf" | tail -1 || true
        echo ""
        echo "band gap"
        grep ':GAP' "$CASE.scf" | tail -1 || true
    } > "${CASE}_PBE_noSOC_summary.txt"

done

##### step 15: collect all noSOC results #####
OUT="$BASE_DIR/PBE_noSOC_summary.txt"
rm -f "$OUT"

for CASE in $CASE_LIST; do

    NOSOC_SCF="$BASE_DIR/1_PBE_noSOC/$CASE/$CASE.scf"

    echo "==========================================" >> "$OUT"
    echo "$CASE PBE noSOC" >> "$OUT"
    echo "==========================================" >> "$OUT"
    echo "" >> "$OUT"

    grep ':ENE' "$NOSOC_SCF" | tail -1 >> "$OUT" || true
    grep ':FER' "$NOSOC_SCF" | tail -1 >> "$OUT" || true
    grep ':BAN' "$NOSOC_SCF" | tail -1 >> "$OUT" || true
    grep ':GAP' "$NOSOC_SCF" | tail -1 >> "$OUT" || true
    echo "" >> "$OUT"

done

cd "$BASE_DIR"

echo ""
echo "All PBE noSOC calculations finished."
echo ""
echo "Summary saved to:"
echo "$OUT"
echo ""
echo "Next run:"
echo "python3 run_2_extract_noSOC_charges.py"
