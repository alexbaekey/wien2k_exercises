#!/usr/bin/env bash
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

CASE_LIST="InAs Si GaAs"
#CASE_LIST="InAs"
#CASE_LIST="Si"
#CASE_LIST="GaAs"

#NOTE need to check that EMAX is 5 when prompted
# need to manually write n_x, n_y, n_z=5

CC="0.00001"
EC="0.00001"

##### HSE run commands #####
HF_NOSOC_CMD="run_lapw -hf"
HF_SOC_CMD="run_lapw -hf -so"

##### step 2: recreate HSE directories #####
rm -rf "$BASE_DIR/3_HSE_noSOC"
rm -rf "$BASE_DIR/4_HSE_SOC"

mkdir -p "$BASE_DIR/3_HSE_noSOC"
mkdir -p "$BASE_DIR/4_HSE_SOC"

##### helper: pause for verification #####
pause_check() {
    echo ""
    echo "Please check the files printed above."
    echo "If something looks wrong, press Ctrl-C and fix it manually."
    read -r -p "Press Enter to continue..."
}

##### step 3: loop over materials #####
for CASE in $CASE_LIST; do
    PBE_NOSOC_DIR="$BASE_DIR/1_PBE_noSOC/$CASE/$CASE"
    PBE_SOC_DIR="$BASE_DIR/2_PBE_SOC/$CASE/$CASE"

    HSE_NOSOC_DIR="$BASE_DIR/3_HSE_noSOC/$CASE/$CASE"
    HSE_SOC_DIR="$BASE_DIR/4_HSE_SOC/$CASE/$CASE"

    PBE_NOSOC_SCF="$PBE_NOSOC_DIR/${CASE}.scf"
    PBE_SOC_SCF="$PBE_SOC_DIR/${CASE}.scf"

    echo ""
    echo "=========================================="
    echo "Preparing HSE noSOC for $CASE"
    echo "=========================================="

    ##### step 4: check PBE noSOC calculation #####
    if [ ! -d "$PBE_NOSOC_DIR" ]; then
        echo "ERROR: missing converged PBE noSOC directory:"
        echo "$PBE_NOSOC_DIR"
        exit 1
    fi

    ##### step 6: copy converged PBE noSOC to HSE noSOC #####
    mkdir -p "$BASE_DIR/3_HSE_noSOC/$CASE"
    cp -r "$PBE_NOSOC_DIR" "$HSE_NOSOC_DIR"

    ##### step 7: go into HSE noSOC directory #####
    cd "$HSE_NOSOC_DIR"

    rm -f .lcore
    rm -f *.broyd* *.error
    rm -f "${CASE}.clmcor"

    x lcore 

    ##### step 8: initialize HSE noSOC #####
    echo ""
    echo "Running init_hf_lapw for $CASE HSE noSOC"
    echo "Read the screen carefully."
    echo "Do NOT choose a reduced k-mesh."
    echo "At the k-mesh prompt, enter:"
    echo "  0"
    echo "  5"
    echo "  5"
    echo "  5"
    init_hf_lapw

    ##### step 10: verify HSE noSOC files before running #####
    echo ""
    echo "Important HSE noSOC checks for $CASE:"
    echo "----- ${CASE}.inhf -----"
    cat "${CASE}.inhf"
    echo ""
    echo "----- ${CASE}.in1 / ${CASE}.in1c -----"
    grep -ni "emax\|emin" "${CASE}.in1" "${CASE}.in1c" 2>/dev/null || true

    pause_check

    ##### step 11: run HSE noSOC #####
    echo ""
    echo "Running HSE noSOC for $CASE"
    $HF_NOSOC_CMD -cc "$CC" -ec "$EC"

    ##### step 12: print HSE noSOC info #####
    echo ""
    echo "HSE noSOC results for $CASE"

    echo "total energy"
    grep ':ENE' "${CASE}.scf" | tail -1 || true

    echo "Fermi energy"
    grep ':FER' "${CASE}.scf" | tail -1 || true

    echo "number of occupied bands"
    grep ':BAN' "${CASE}.scf" | tail -1 || true

    echo "band gap"
    grep ':GAP' "${CASE}.scf" | tail -1 || true

    {
        echo "$CASE HSE noSOC"
        echo ""
        #echo "NB_occ from PBE noSOC = $NB_OCC_NOSOC"
        #echo "nband used = $NBAND_NOSOC"
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
    } > "${CASE}_HSE_noSOC_summary.txt"

    echo ""
    echo "=========================================="
    echo "Preparing HSE withSOC for $CASE"
    echo "=========================================="

    ##### step 13: check PBE SOC calculation for SOC NB_occ #####
    if [ ! -d "$PBE_SOC_DIR" ]; then
        echo "ERROR: missing converged PBE SOC directory:"
        echo "$PBE_SOC_DIR"
        echo "Need this to get NB_occ for the SOC HSE nband."
        exit 1
    fi

    ##### step 14: get SOC NB_occ and nband #####
    # check case.scf in 1_scf/, search BAN, then write # bands to be 2 more than # occupied

    ##### step 15: copy converged HSE noSOC to HSE SOC #####
    mkdir -p "$BASE_DIR/4_HSE_SOC/$CASE"
    cp -r "$HSE_NOSOC_DIR" "$HSE_SOC_DIR"

    ##### step 16: go into HSE SOC directory #####
    cd "$HSE_SOC_DIR"

    ##### step 17: initialize SOC from converged HSE noSOC #####
    echo ""
    echo "Running init_so_lapw for $CASE HSE SOC"
    echo "Do this interactively. Do not use -b."
    echo "For EMAX, accept/default 5.0 Ry."
    echo "For RLOs, usually choose NONE unless your instructor says otherwise."
    echo "For spin-polarized case, answer N."
    init_so_lapw

    ##### step 20: verify HSE SOC files before running #####
    echo ""
    echo "Important HSE SOC checks for $CASE:"
    echo "----- ${CASE}.inhf -----"
    cat "${CASE}.inhf"
    echo ""
    echo "----- ${CASE}.in1 / ${CASE}.in1c -----"
    grep -ni "emax\|emin" "${CASE}.in1" "${CASE}.in1c" 2>/dev/null || true
    echo ""
    echo "----- ${CASE}.inso -----"
    grep -ni "emax\|emin" "${CASE}.inso" 2>/dev/null || true

    pause_check

    rm -f .lcore
    rm -f *.broyd* *.error
    rm -f "${CASE}.clmcor"

    x lcore



    ##### step 21: run HSE with SOC #####
    echo ""
    echo "Running HSE withSOC for $CASE"
    $HF_SOC_CMD -cc "$CC" -ec "$EC"

    ##### step 22: print HSE SOC info #####
    echo ""
    echo "HSE withSOC results for $CASE"

    echo "total energy"
    grep ':ENE' "${CASE}.scf" | tail -1 || true

    echo "Fermi energy"
    grep ':FER' "${CASE}.scf" | tail -1 || true

    echo "number of occupied bands"
    grep ':BAN' "${CASE}.scf" | tail -1 || true

    echo "band gap"
    grep ':GAP' "${CASE}.scf" | tail -1 || true

    {
        echo "$CASE HSE withSOC"
        echo ""
        #echo "NB_occ from PBE SOC = $NB_OCC_SOC"
        #echo "nband used = $NBAND_SOC"
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
    } > "${CASE}_HSE_SOC_summary.txt"

done

##### step 23: collect all HSE results #####
OUT="$BASE_DIR/HSE_summary.txt"
rm -f "$OUT"

for CASE in $CASE_LIST; do

    HSE_NOSOC_SCF="$BASE_DIR/3_HSE_noSOC/$CASE/$CASE/${CASE}.scf"
    HSE_SOC_SCF="$BASE_DIR/4_HSE_SOC/$CASE/$CASE/${CASE}.scf"

    echo "==========================================" >> "$OUT"
    echo "$CASE" >> "$OUT"
    echo "==========================================" >> "$OUT"
    echo "" >> "$OUT"

    echo "HSE noSOC" >> "$OUT"
    grep ':ENE' "$HSE_NOSOC_SCF" | tail -1 >> "$OUT" || true
    grep ':FER' "$HSE_NOSOC_SCF" | tail -1 >> "$OUT" || true
    grep ':BAN' "$HSE_NOSOC_SCF" | tail -1 >> "$OUT" || true
    grep ':GAP' "$HSE_NOSOC_SCF" | tail -1 >> "$OUT" || true
    echo "" >> "$OUT"

    echo "HSE withSOC" >> "$OUT"
    grep ':ENE' "$HSE_SOC_SCF" | tail -1 >> "$OUT" || true
    grep ':FER' "$HSE_SOC_SCF" | tail -1 >> "$OUT" || true
    grep ':BAN' "$HSE_SOC_SCF" | tail -1 >> "$OUT" || true
    grep ':GAP' "$HSE_SOC_SCF" | tail -1 >> "$OUT" || true
    echo "" >> "$OUT"

done

echo ""
echo "All HSE calculations finished."
echo ""
echo "Summary saved to:"
echo "$OUT"
