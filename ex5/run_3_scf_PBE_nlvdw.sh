#!/usr/bin/env bash
set -e


# Need this template file
#cp /opt/WIEN2k_23.2/SRC_templates/case.innlvdw ~/Desktop/ucf_research/PauloLab/ab_DFT_tutorial_Paulo/ex5/


CASE="bilayer_graphene"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

D_LIST="2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8"

TEMPLATE_INNLVDW="$BASE_DIR/case.innlvdw"
CASE_INNLVDW="$BASE_DIR/${CASE}.innlvdw"

KERNEL_TYPE="1"

##### step 1: recreate PBE+nlvdw directory #####
rm -rf "$BASE_DIR/3_scf_PBE_nlvdw"
mkdir -p "$BASE_DIR/3_scf_PBE_nlvdw"

##### step 2: check for template case.innlvdw file #####
if [ ! -f "$TEMPLATE_INNLVDW" ]; then
    echo "ERROR: missing $TEMPLATE_INNLVDW"
    echo "Copy case.innlvdw from the WIEN2k source/templates into the top directory first."
    exit 1
fi

##### step 3: modify and rename case.innlvdw to bilayer_graphene.innlvdw #####
cp "$TEMPLATE_INNLVDW" "$CASE_INNLVDW"

##### Replace XX kernel type with 1 on the first line only #####
awk -v kernel="$KERNEL_TYPE" '
NR == 1 {
    sub(/^XX/, kernel)
}
{
    print
}
' "$CASE_INNLVDW" > "${CASE_INNLVDW}.tmp"

mv "${CASE_INNLVDW}.tmp" "$CASE_INNLVDW"

##### step 4: print modified innlvdw file #####
echo ""
echo "Using modified ${CASE}.innlvdw:"
cat "$CASE_INNLVDW"
echo ""

##### step 5: loop over interlayer distances #####
for D in $D_LIST; do

    SRC_DIR="$BASE_DIR/1_scf_PBE/d_${D}/$CASE"
    RUN_DIR="$BASE_DIR/3_scf_PBE_nlvdw/d_${D}/$CASE"

    echo ""
    echo "=========================================="
    echo "Running PBE+nlvdw for d = $D A"
    echo "=========================================="

    ##### step 6: check PBE calculation exists #####
    if [ ! -d "$SRC_DIR" ]; then
        echo "ERROR: missing $SRC_DIR"
        echo "Run ./run_1_scf_PBE.sh first."
        exit 1
    fi

    ##### step 7: copy converged PBE calculation #####
    mkdir -p "$BASE_DIR/3_scf_PBE_nlvdw/d_${D}"
    cp -r "$SRC_DIR" "$RUN_DIR"

    ##### step 8: copy modified innlvdw file into case directory #####
    cp "$CASE_INNLVDW" "$RUN_DIR/${CASE}.innlvdw"

    ##### step 9: go into run directory #####
    cd "$RUN_DIR"

    ##### step 10: show copied innlvdw file #####
    echo "Copied ${CASE}.innlvdw:"
    cat "${CASE}.innlvdw"

    ##### step 11: run SCF with nlvdw #####
    run_lapw -p -nlvdw -cc 0.00001 -ec 0.00001

    ##### step 12: print run info #####
    echo "total energy"
    grep ':ENE' "${CASE}.scf" | tail -1

    echo "Fermi energy"
    grep ':FER' "${CASE}.scf" | tail -1

done

##### step 13: collect energies #####
OUT="$BASE_DIR/3_scf_PBE_nlvdw/energy_vs_d_PBE_nlvdw.dat"
rm -f "$OUT"

for D in $D_LIST; do
    SCF="$BASE_DIR/3_scf_PBE_nlvdw/d_${D}/$CASE/${CASE}.scf"

    if [ -f "$SCF" ]; then
        ENE=$(grep ':ENE' "$SCF" | tail -1 | awk '{print $NF}')
        echo "$D $ENE" >> "$OUT"
    else
        echo "WARNING: missing $SCF"
    fi
done

echo ""
echo "Saved PBE+nlvdw energies to:"
echo "$OUT"
