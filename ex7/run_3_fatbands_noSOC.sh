#!/usr/bin/env bash
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

CASE_LIST="Gr hBN MoSe2 WSe2"

##### change this path if needed #####
XCRYSDEN="/opt/xcrysden-1.6.2/xcrysden"

##### source converged noSOC calculations #####
PBE_NOSOC_BASE="$BASE_DIR/1_PBE_noSOC"

##### output directory #####
OUT_BASE="$BASE_DIR/3_fatbands_noSOC"

##### step 1: recreate fatband directory #####
rm -rf "$OUT_BASE"
mkdir -p "$OUT_BASE"

##### step 2: check .machines file #####
if [ ! -f "$BASE_DIR/.machines" ]; then
    echo "ERROR: missing $BASE_DIR/.machines"
    echo "Create a .machines file in the top directory before running this script."
    exit 1
fi

##### step 3: loop over materials #####
for CASE in $CASE_LIST; do

    echo ""
    echo "=========================================="
    echo "Fatbands noSOC for $CASE"
    echo "=========================================="

    SRC="$PBE_NOSOC_BASE/$CASE"
    RUN_DIR="$OUT_BASE/$CASE"
    RESULTS_DIR="$OUT_BASE/fatbands_output/$CASE"

    ##### step 4: check source directory #####
    if [ ! -d "$SRC" ]; then
        echo "ERROR: missing noSOC source directory:"
        echo "$SRC"
        echo "Run ./run_1_scf_noSOC.sh first."
        exit 1
    fi

    if [ ! -f "$SRC/${CASE}.scf" ]; then
        echo "ERROR: missing SCF file:"
        echo "$SRC/${CASE}.scf"
        echo "The noSOC SCF does not look finished."
        exit 1
    fi

    ##### step 5: copy converged noSOC calculation #####
    rm -rf "$RUN_DIR"
    cp -r "$SRC" "$RUN_DIR"

    ##### step 6: copy .machines file #####
    cp "$BASE_DIR/.machines" "$RUN_DIR/.machines"

    ##### step 7: make results directory #####
    mkdir -p "$RESULTS_DIR"

    ##### step 8: go into fatband directory #####
    cd "$RUN_DIR"

    ##### step 9: generate k-path with XCrySDen #####
    echo ""
    echo "Generate k-path for $CASE using XCrySDen."
    echo "Recommended path for these 2D hexagonal materials:"
    echo "    GAMMA - K - M - GAMMA"
    echo ""
    echo "Use around 100-200 total k-points."
    echo "Save as:"
    echo "    ${CASE}.klist_band"
    echo ""

    "$XCRYSDEN"

    ##### step 10: check that XCrySDen created klist_band #####
    if [ ! -f "${CASE}.klist_band" ]; then
        echo "ERROR: ${CASE}.klist_band was not found."
        echo "You need to save the XCrySDen k-path as ${CASE}.klist_band."
        exit 1
    fi

    ##### step 11: save this k-path for record keeping #####
    cp "${CASE}.klist_band" "$RESULTS_DIR/${CASE}_GKMGM.klist_band"

    ##### step 12: remove old band/fatband files if present #####
    rm -f "${CASE}.energy" \
          "${CASE}.energy_*" \
          "${CASE}.qtl" \
          "${CASE}.qtl*" \
          "${CASE}.output1" \
          "${CASE}.output2" \
          "${CASE}.outputqtl" \
          "${CASE}.error" \
          2>/dev/null || true

    ##### step 13: run band eigenvalues along k-path #####
    echo ""
    echo "Running lapw1 -band for $CASE"
    x lapw1 -band -p

    ##### step 14: run lapw2 with qtl output for fatbands #####
    echo ""
    echo "Running lapw2 -band -qtl for $CASE"
    x lapw2 -band -qtl -p

    ##### step 15: save fatband summary #####
    {
        echo "$CASE PBE noSOC fatband preparation"
        echo ""
        echo "Recommended path:"
        echo "GAMMA - K - M - GAMMA"
        echo ""
        echo "Total energy"
        grep ':ENE' "${CASE}.scf" | tail -1 || true
        echo ""
        echo "Fermi energy"
        grep ':FER' "${CASE}.scf" | tail -1 || true
        echo ""
        echo "Number of occupied bands"
        grep ':BAN' "${CASE}.scf" | tail -1 || true
        echo ""
        echo "Band gap"
        grep ':GAP' "${CASE}.scf" | tail -1 || true
        echo ""
        echo "Generated files"
        ls -1 "${CASE}.energy"* "${CASE}.qtl"* "${CASE}.klist_band" 2>/dev/null || true
    } > "$RESULTS_DIR/${CASE}_PBE_noSOC_fatband_summary.txt"

    ##### step 16: copy important outputs #####
    cp "${CASE}.klist_band" "$RESULTS_DIR/${CASE}.klist_band" 2>/dev/null || true
    cp "${CASE}.energy" "$RESULTS_DIR/${CASE}.energy" 2>/dev/null || true
    cp "${CASE}.qtl" "$RESULTS_DIR/${CASE}.qtl" 2>/dev/null || true
    cp "${CASE}.scf" "$RESULTS_DIR/${CASE}.scf" 2>/dev/null || true

    echo ""
    echo "Finished noSOC fatband preparation for $CASE"
    echo "Results copied to:"
    echo "$RESULTS_DIR"

done

cd "$BASE_DIR"

echo ""
echo "All noSOC fatband preparations finished."
echo ""
echo "Results are in:"
echo "$OUT_BASE"
