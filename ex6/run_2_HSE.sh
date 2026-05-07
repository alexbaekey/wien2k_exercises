#!/usr/bin/env bash
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

CASE_LIST="Si GaAs InAs"

CC="0.00001"
EC="0.00001"

PATCH_NBAND="$BASE_DIR/patch_inhf_nband.py"
PATCH_EMAX="$BASE_DIR/patch_emax_5.py"

##### HSE run commands #####
HF_NOSOC_CMD="run_lapw -hf"
HF_SOC_CMD="run_lapw -hf -so"

##### step 1: check helper scripts #####
if [ ! -f "$PATCH_NBAND" ]; then
    echo "ERROR: missing $PATCH_NBAND"
    exit 1
fi

if [ ! -f "$PATCH_EMAX" ]; then
    echo "ERROR: missing $PATCH_EMAX"
    exit 1
fi

##### step 2: recreate HSE directories #####
rm -rf "$BASE_DIR/3_HSE_noSOC"
rm -rf "$BASE_DIR/4_HSE_SOC"

mkdir -p "$BASE_DIR/3_HSE_noSOC"
mkdir -p "$BASE_DIR/4_HSE_SOC"

##### helper: get occupied band number from :BAN lines #####
get_nb_occ() {
    local scf_file="$1"

    if [ ! -f "$scf_file" ]; then
        echo "ERROR: missing $scf_file"
        exit 1
    fi

    local nb
    nb=$(awk '
    /^:BAN/ {
        occ = $5
        if (occ > 0.000001) {
            band = $2
        }
    }
    END {
        if (band != "") print band
    }
    ' "$scf_file")

    if [ -z "$nb" ]; then
        echo "ERROR: could not extract occupied band count from $scf_file"
        echo "Check with:"
        echo "grep ':BAN' $scf_file"
        exit 1
    fi

    echo "$nb"
}

##### helper: patch nband in case.inhf #####
patch_inhf_nband() {
    local case="$1"
    local nband="$2"
    local file="${case}.inhf"

    if [ ! -f "$file" ]; then
        echo "ERROR: missing $file"
        echo "init_hf_lapw did not create it, or the filename is different."
        exit 1
    fi

    cp "$file" "${file}_before_nband_patch"

    python3 "$PATCH_NBAND" "$file" "$nband"

    echo ""
    echo "Current nband line in $file:"
    grep -ni "nband" "$file" || true
}

##### helper: patch emax to 5.0 #####
patch_emax_5() {
    local file="$1"

    if [ ! -f "$file" ]; then
        echo "WARNING: missing $file, skipping emax patch for this file"
        return
    fi

    cp "$file" "${file}_before_emax_patch"

    python3 "$PATCH_EMAX" "$file"

    echo ""
    echo "Current EMIN/EMAX lines in $file:"
    grep -ni "emax\|emin" "$file" || true
}

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

    ##### step 5: get noSOC NB_occ and nband #####
    NB_OCC_NOSOC=$(get_nb_occ "$PBE_NOSOC_SCF")
    NBAND_NOSOC=$((NB_OCC_NOSOC + 2))

    echo "PBE noSOC NB_occ = $NB_OCC_NOSOC"
    echo "HSE noSOC nband  = $NBAND_NOSOC"

    ##### step 6: copy converged PBE noSOC to HSE noSOC #####
    mkdir -p "$BASE_DIR/3_HSE_noSOC/$CASE"
    cp -r "$PBE_NOSOC_DIR" "$HSE_NOSOC_DIR"

    ##### step 7: go into HSE noSOC directory #####
    cd "$HSE_NOSOC_DIR"

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

    ##### step 9: patch HSE noSOC input files #####
    patch_inhf_nband "$CASE" "$NBAND_NOSOC"

    #if [ -f "${CASE}.in1c" ]; then
    #    patch_emax_5 "${CASE}.in1c"
    #else
    #    patch_emax_5 "${CASE}.in1"
    #fi

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
        echo "NB_occ from PBE noSOC = $NB_OCC_NOSOC"
        echo "nband used = $NBAND_NOSOC"
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
    NB_OCC_SOC=$(get_nb_occ "$PBE_SOC_SCF")
    NBAND_SOC=$((NB_OCC_SOC + 2))

    echo "PBE SOC NB_occ = $NB_OCC_SOC"
    echo "HSE SOC nband  = $NBAND_SOC"

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

    ##### step 18: DO NOT run init_hf_lapw again #####
    ##### case.inhf already exists because this directory was copied from HSE noSOC. #####
    ##### Just patch nband for the SOC calculation. #####

    ##### step 19: patch HSE SOC input files #####
    patch_inhf_nband "$CASE" "$NBAND_SOC"

    #if [ -f "${CASE}.in1c" ]; then
    #    patch_emax_5 "${CASE}.in1c"
    #else
    #    patch_emax_5 "${CASE}.in1"
    #fi

    patch_emax_5 "${CASE}.inso"

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
        echo "NB_occ from PBE SOC = $NB_OCC_SOC"
        echo "nband used = $NBAND_SOC"
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
