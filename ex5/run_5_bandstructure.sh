#!/usr/bin/env bash
set -e

CASE="bilayer_graphene"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

METHOD_DIR="2_scf_PBE_dftd3"
D0="3.3"

##### step 1: recreate band structure directory #####
rm -rf "$BASE_DIR/4_bandstructure"
mkdir -p "$BASE_DIR/4_bandstructure"

##### step 2: copy chosen converged calculation #####
cp -r "$BASE_DIR/$METHOD_DIR/d_${D0}/$CASE" "$BASE_DIR/4_bandstructure/"

##### step 3: go into case directory #####
cd "$BASE_DIR/4_bandstructure/$CASE"

##### step 4: check required files #####
if [ ! -f "${CASE}.struct" ]; then
    echo "ERROR: missing ${CASE}.struct"
    exit 1
fi

if [ ! -f "${CASE}.scf" ]; then
    echo "ERROR: missing ${CASE}.scf"
    exit 1
fi

##### step 5: backup original struct before line fixes #####
cp "${CASE}.struct" "${CASE}.struct_beforelinefixes"

##### step 6: fix lattice-line spacing issue #####
##### ASE sometimes writes:
##### 90.000000120.000000
##### instead of:
##### 90.000000 120.000000
sed -i 's/90\.000000120\.000000/90.000000 120.000000/g' "${CASE}.struct"

##### step 7: remove non-WIEN2k Precise positions block #####
##### XCrySDen may fail to convert the struct if this extra ASE block is present.
sed -i '/^Precise positions/,$d' "${CASE}.struct"

##### step 8: show cleaned struct header #####
echo ""
echo "Cleaned struct header:"
head -4 "${CASE}.struct"
echo ""

##### step 9: generate k-path with XCrySDen #####
#echo ""
#echo "Opening XCrySDen."
#echo ""
#echo "In XCrySDen:"
#echo "  1. File -> Open WIEN2k -> Open WIEN2k Struct file"
#echo "  2. Open ${CASE}.struct"
#echo "  3. Use the WIEN2k k-path tool"
#echo "  4. Create the path Gamma - K - M - Gamma"
#echo "  5. Save it as ${CASE}.klist_band"
#echo ""

#xcrysden DOESNT WORK, ERROR REALTED TO .xcr file ??
#~/Desktop/ucf_research/PauloLab/ab_DFT_tutorial_Paulo/ex2/xcrysden-1.6.2/xcrysden

python3 ../../generate_klist_band.py

##### step 10: check that klist_band was created #####
if [ ! -f "${CASE}.klist_band" ]; then
    echo "ERROR: ${CASE}.klist_band was not created"
    echo "Open XCrySDen again and save the path as ${CASE}.klist_band"
    exit 1
fi

##### step 11: run band structure #####
x lapw1 -band

x lapw2 -band -qtl

x spaghetti -d

write_insp_lapw

##### step 12: insert Fermi energy into insp file if needed #####
EF=$(grep ':FER' "$CASE.scf" | tail -1 | awk '{print $NF}')

if grep -q "x.xxxx" "${CASE}.insp"; then
    sed -i "s/x.xxxx/${EF}/" "${CASE}.insp"
fi

##### step 13: make spaghetti plot #####
x spaghetti

##### step 14: print useful info #####
echo ""
echo "Fermi energy:"
grep ':FER' "$CASE.scf" | tail -1

echo ""
echo "Band structure files are in:"
pwd

echo ""
echo "Important output files:"
ls -lh \
    "${CASE}.struct" \
    "${CASE}.struct_beforelinefixes" \
    "${CASE}.klist_band" \
    "${CASE}.bands.agr" \
    "${CASE}.spaghetti_ps" 2>/dev/null || true
