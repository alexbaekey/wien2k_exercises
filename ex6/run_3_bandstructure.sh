#!/usr/bin/env bash

set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

CASE_LIST="Si GaAs InAs"

##### change this path if needed #####
XCRYSDEN="$HOME/Desktop/ucf_research/PauloLab/ab_DFT_tutorial_Paulo/ex2/xcrysden-1.6.2/xcrysden"

##### source converged SOC calculations #####
PBE_SOC_BASE="$BASE_DIR/2_PBE_SOC"
HSE_SOC_BASE="$BASE_DIR/4_HSE_SOC"

##### output directory #####
OUT_BASE="$BASE_DIR/5_bandstructures_SOC"

##### step 1: recreate band structure directory #####
rm -rf "$OUT_BASE"
mkdir -p "$OUT_BASE"

##### step 2: loop over materials #####
for CASE in $CASE_LIST; do

    echo ""
    echo "=========================================="
    echo "Band structures for $CASE"
    echo "=========================================="

    PBE_SRC="$PBE_SOC_BASE/$CASE/$CASE"
    HSE_SRC="$HSE_SOC_BASE/$CASE/$CASE"

    PBE_RUN="$OUT_BASE/$CASE/PBE_SOC/$CASE"
    HSE_RUN="$OUT_BASE/$CASE/HSE_SOC/$CASE"

    RESULTS_DIR="$OUT_BASE/$CASE/results"

    ##### step 3: check source directories #####
    if [ ! -d "$PBE_SRC" ]; then
        echo "ERROR: missing PBE SOC source directory:"
        echo "$PBE_SRC"
        exit 1
    fi

    if [ ! -d "$HSE_SRC" ]; then
        echo "ERROR: missing HSE SOC source directory:"
        echo "$HSE_SRC"
        exit 1
    fi

    ##### step 4: copy PBE SOC calculation #####
    rm -rf "$OUT_BASE/$CASE/PBE_SOC"
    mkdir -p "$OUT_BASE/$CASE/PBE_SOC"
    cp -r "$PBE_SRC" "$PBE_RUN"

    ##### step 5: copy HSE SOC calculation #####
    rm -rf "$OUT_BASE/$CASE/HSE_SOC"
    mkdir -p "$OUT_BASE/$CASE/HSE_SOC"
    cp -r "$HSE_SRC" "$HSE_RUN"

    mkdir -p "$RESULTS_DIR"

    ##### step 6: go into PBE band structure directory #####
    cd "$PBE_RUN"

    ##### step 7: generate k-path with XCrySDen #####
    echo ""
    echo "Generate k-path for $CASE using XCrySDen."
    echo "Use path: X - GAMMA - K"
    echo "Use 100 k-points."
    echo "Save as: ${CASE}.klist_band"
    echo ""

    "$XCRYSDEN"

    ##### step 8: check that XCrySDen created klist_band #####
    if [ ! -f "${CASE}.klist_band" ]; then
        echo "ERROR: ${CASE}.klist_band was not found."
        echo "You need to save the XCrySDen k-path as ${CASE}.klist_band."
        exit 1
    fi

    ##### step 9: save this k-path for later reuse #####
    cp "${CASE}.klist_band" "$RESULTS_DIR/${CASE}_XGK.klist_band"

    ##### step 10: run PBE SOC band structure #####
    echo ""
    echo "Running PBE SOC band structure for $CASE"

    #rm -f "${CASE}.irrep"* \
    #      "${CASE}.qtl"* \
    #      "${CASE}.spaghetti"* \
    #      "${CASE}.outputsp"* \
    #      "${CASE}.energy"* \
    #      2>/dev/null || true

    x lapw1 -band

    x lapwso -band

    write_insp_lapw

    #EF=$(grep ':FER' "${CASE}.scf" | tail -1 | awk '{print $NF}')

    #if [ -n "$EF" ]; then
    #    sed -i "s/x.xxxx/${EF}/" "${CASE}.insp" || true
    #fi

    x spaghetti -so

    ##### step 11: copy PBE outputs #####
    cp "${CASE}.insp" "$RESULTS_DIR/${CASE}_PBE_SOC.insp" 2>/dev/null || true
    cp "${CASE}.spaghetti_ps" "$RESULTS_DIR/${CASE}_PBE_SOC.spaghetti_ps" 2>/dev/null || true
    cp "${CASE}.spaghetti_ene" "$RESULTS_DIR/${CASE}_PBE_SOC.spaghetti_ene" 2>/dev/null || true
    cp "${CASE}.energyso" "$RESULTS_DIR/${CASE}_PBE_SOC.energyso" 2>/dev/null || true

    ##### step 12: go into HSE band structure directory #####
    cd "$HSE_RUN"

    ##### step 13: reuse the same XCrySDen k-path for HSE #####
    cp "$RESULTS_DIR/${CASE}_XGK.klist_band" "${CASE}.klist_band"

    ##### step 14: run HSE SOC band structure #####
    echo ""
    echo "Running HSE SOC band structure for $CASE"

    #rm -f "${CASE}.irrep"* \
    #      "${CASE}.qtl"* \
    #      "${CASE}.spaghetti"* \
    #      "${CASE}.outputsp"* \
    #      "${CASE}.energy"* \
    #      2>/dev/null || true

    ##### HSE band commands are different from PBE #####
    #x lapw1 -band
    #x hf -band
    #x lapwso -band -hf

    run_bandplothf_lapw -so

    write_insp_lapw

    #EF=$(grep ':FER' "${CASE}.scf" | tail -1 | awk '{print $NF}')

    #if [ -n "$EF" ]; then
    #    sed -i "s/x.xxxx/${EF}/" "${CASE}.insp" || true
    #fi

    x spaghetti -so -hf

    ##### step 15: copy HSE outputs #####
    cp "${CASE}.insp" "$RESULTS_DIR/${CASE}_HSE_SOC.insp" 2>/dev/null || true
    cp "${CASE}.spaghetti_ps" "$RESULTS_DIR/${CASE}_HSE_SOC.spaghetti_ps" 2>/dev/null || true
    cp "${CASE}.spaghetti_ene" "$RESULTS_DIR/${CASE}_HSE_SOC.spaghetti_ene" 2>/dev/null || true
    cp "${CASE}.energyso" "$RESULTS_DIR/${CASE}_HSE_SOC.energyso" 2>/dev/null || true

done

echo ""
echo "Band structure calculations finished."
echo ""
echo "Results are in:"
echo "$OUT_BASE"
