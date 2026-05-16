#!/usr/bin/env bash
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

CASE_LIST="Si GaAs InAs"

##### calculation parameters #####
ECUT="-6.0"       # core/valence separation energy
RKMAX="7.0"
CC="0.00001"
EC="0.00001"

##### step 1: recreate calculation directories #####
rm -rf "$BASE_DIR/1_PBE_noSOC"
rm -rf "$BASE_DIR/2_PBE_SOC"

mkdir -p "$BASE_DIR/1_PBE_noSOC"
mkdir -p "$BASE_DIR/2_PBE_SOC"

##### step 2: loop over materials #####
for CASE in $CASE_LIST; do

    STRUCT_FILE="$BASE_DIR/${CASE}.struct"

    NOSOC_DIR="$BASE_DIR/1_PBE_noSOC/$CASE/$CASE"
    SOC_DIR="$BASE_DIR/2_PBE_SOC/$CASE/$CASE"

    echo ""
    echo "=========================================="
    echo "Running PBE noSOC for $CASE"
    echo "=========================================="

    ##### step 3: check struct file #####
    if [ ! -f "$STRUCT_FILE" ]; then
        echo "ERROR: missing $STRUCT_FILE"
        echo "Run python3 run_0_make_structs.py first."
        exit 1
    fi

    ##### step 4: make noSOC calculation directory #####
    mkdir -p "$NOSOC_DIR"

    ##### step 5: copy struct file #####
    cp "$STRUCT_FILE" "$NOSOC_DIR/${CASE}.struct"

    cp $BASE_DIR/.machines $NOSOC_DIR

    ##### step 6: go into noSOC directory #####
    cd "$NOSOC_DIR"

    ##### step 7: run sgroup #####
    x sgroup

    ##### step 8: replace struct with sgroup struct if created #####
    if [ -f "${CASE}.struct_sgroup" ]; then
        cp "${CASE}.struct" "${CASE}.struct_before_sgroup"
        cp "${CASE}.struct_sgroup" "${CASE}.struct"
    else
        echo "WARNING: ${CASE}.struct_sgroup was not created"
    fi

    ##### step 9: initialize PBE noSOC calculation #####
    init_lapw -b -ecut "$ECUT" -rkmax "$RKMAX" -numk 125

    ##### step 10: overwrite k-mesh with exact 5 x 5 x 5 grid #####
    ##### Important: do not include an extra final 0 here.
    ##### The first 0 tells kgen to use manual divisions.
    printf "0\n5 5 5\n" | x kgen

    echo ""
    echo "kgen result for $CASE noSOC:"
    grep -i "k-points generated" "${CASE}.outputkgen" || true
    grep -i "ndiv" "${CASE}.outputkgen" || true
    echo ""

    ##### step 11: regenerate starting density after replacing klist #####
    #x dstart

    ##### step 12: run noSOC SCF #####
    run_lapw -p -cc "$CC" -ec "$EC"

    ##### step 13: print noSOC info #####
    echo ""
    echo "PBE noSOC results for $CASE"

    echo "total energy"
    grep ':ENE' "${CASE}.scf" | tail -1 || true

    echo "Fermi energy"
    grep ':FER' "${CASE}.scf" | tail -1 || true

    echo "number of occupied bands"
    grep ':BAN' "${CASE}.scf" | tail -1 || true

    echo "band gap"
    grep ':GAP' "${CASE}.scf" | tail -1 || true

    ##### step 14: save noSOC summary #####
    {
        echo "$CASE PBE noSOC"
        echo ""
        echo "total energy"
        grep ':ENE' "${CASE}.scf" | tail -1 || true
        echo ""
        echo "Fermi energy"
        grep ':FER' "${CASE}.scf" | tail -1 || true
        echo ""
        echo "number of occupied bands"
        grep ':BAN' "${CASE}.scf" | tail -1 || true
        echo ""
        echo "band gap"
        grep ':GAP' "${CASE}.scf" | tail -1 || true
    } > "${CASE}_PBE_noSOC_summary.txt"

    echo ""
    echo "=========================================="
    echo "Running PBE withSOC for $CASE"
    echo "=========================================="

    ##### step 15: copy converged noSOC calculation to SOC directory #####
    mkdir -p "$BASE_DIR/2_PBE_SOC/$CASE"
    cp -r "$NOSOC_DIR" "$SOC_DIR"

    ##### step 16: go into SOC directory #####
    cd "$SOC_DIR"

    ##### step 17: initialize SOC from converged noSOC calculation #####
    #init_so_lapw -b
    init_so_lapw

    ##### step 18: run SOC SCF #####
    run_lapw -p -so -cc "$CC" -ec "$EC"

    ##### step 19: print SOC info #####
    echo ""
    echo "PBE withSOC results for $CASE"

    echo "total energy"
    grep ':ENE' "${CASE}.scf" | tail -1 || true

    echo "Fermi energy"
    grep ':FER' "${CASE}.scf" | tail -1 || true

    echo "number of occupied bands"
    grep ':BAN' "${CASE}.scf" | tail -1 || true

    echo "band gap"
    grep ':GAP' "${CASE}.scf" | tail -1 || true

    ##### step 20: save SOC summary #####
    {
        echo "$CASE PBE withSOC"
        echo ""
        echo "total energy"
        grep ':ENE' "${CASE}.scf" | tail -1 || true
        echo ""
        echo "Fermi energy"
        grep ':FER' "${CASE}.scf" | tail -1 || true
        echo ""
        echo "number of occupied bands"
        grep ':BAN' "${CASE}.scf" | tail -1 || true
        echo ""
        echo "band gap"
        grep ':GAP' "${CASE}.scf" | tail -1 || true
    } > "${CASE}_PBE_SOC_summary.txt"

done

##### step 21: collect all results #####
OUT="$BASE_DIR/PBE_noHSE_summary.txt"
rm -f "$OUT"

for CASE in $CASE_LIST; do

    NOSOC_SCF="$BASE_DIR/1_PBE_noSOC/$CASE/$CASE/${CASE}.scf"
    SOC_SCF="$BASE_DIR/2_PBE_SOC/$CASE/$CASE/${CASE}.scf"

    echo "==========================================" >> "$OUT"
    echo "$CASE" >> "$OUT"
    echo "==========================================" >> "$OUT"
    echo "" >> "$OUT"

    echo "PBE noSOC" >> "$OUT"
    grep ':ENE' "$NOSOC_SCF" | tail -1 >> "$OUT" || true
    grep ':FER' "$NOSOC_SCF" | tail -1 >> "$OUT" || true
    grep ':BAN' "$NOSOC_SCF" | tail -1 >> "$OUT" || true
    grep ':GAP' "$NOSOC_SCF" | tail -1 >> "$OUT" || true
    echo "" >> "$OUT"

    echo "PBE withSOC" >> "$OUT"
    grep ':ENE' "$SOC_SCF" | tail -1 >> "$OUT" || true
    grep ':FER' "$SOC_SCF" | tail -1 >> "$OUT" || true
    grep ':BAN' "$SOC_SCF" | tail -1 >> "$OUT" || true
    grep ':GAP' "$SOC_SCF" | tail -1 >> "$OUT" || true
    echo "" >> "$OUT"

done

echo ""
echo "All PBE no-HSE calculations finished."
echo ""
echo "Summary saved to:"
echo "$OUT"
