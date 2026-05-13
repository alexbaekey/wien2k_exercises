#!/usr/bin/env bash
set -e

CASE="bilayer_graphene"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

D_LIST="2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8"

C_RMT="1.25"

##### step 1: recreate PBE directory #####
rm -rf "$BASE_DIR/1_scf_PBE"
mkdir -p "$BASE_DIR/1_scf_PBE"

##### step 2: loop over interlayer distances #####
for D in $D_LIST; do

    TAG=$(echo "$D" | sed 's/\./p/g')
    STRUCT_FILE="$BASE_DIR/${CASE}_d_${TAG}.struct"
    RUN_DIR="$BASE_DIR/1_scf_PBE/d_${D}/$CASE"

    echo ""
    echo "=========================================="
    echo "Running bare PBE for d = $D A"
    echo "=========================================="

    ##### step 3: check struct file #####
    if [ ! -f "$STRUCT_FILE" ]; then
        echo "ERROR: missing $STRUCT_FILE"
        echo "Run python3 run_0_make_structs.py first."
        exit 1
    fi

    ##### step 4: make calculation directory #####
    mkdir -p "$RUN_DIR"

    ##### step 5: copy struct file into calculation directory #####
    cp "$STRUCT_FILE" "$RUN_DIR/${CASE}.struct"

    cp $BASE_DIR/.machines $RUN_DIR

    ##### step 6: go into run directory #####
    cd "$RUN_DIR"

    ##### step 7: force smaller carbon RMT #####
    sed -i "s/RMT=[[:space:]]*[0-9.]\+/RMT=    ${C_RMT}/g" "${CASE}.struct"

    ##### step 8: run sgroup #####
    x sgroup

    ##### step 9: replace copied struct with sgroup struct if created #####
    if [ -f "${CASE}.struct_sgroup" ]; then
        cp "${CASE}.struct" "${CASE}.struct_before_sgroup"
        cp "${CASE}.struct_sgroup" "${CASE}.struct"

        ##### force RMT again after sgroup #####
        sed -i "s/RMT=[[:space:]]*[0-9.]\+/RMT=    ${C_RMT}/g" "${CASE}.struct"
    else
        echo "WARNING: ${CASE}.struct_sgroup was not created"
    fi

    ##### step 10: initialize calculation #####
    ##### init_lapw needs numk, but this does not force exact 30 x 30 x 1 #####
    init_lapw

    ##### step 10b: overwrite k-mesh with exact 30 x 30 x 1 grid #####
    x kgen
    # HERE WRITE 
    # 0
    # THEN
    # 30,30,1

    #AUTOMATED
    #echo "Running kgen..."
    #x kgen << EOF
    #0
    #30,30,1
    #EOF

    ##### step 11: replace TETRA by TEMP in case.in2 safely #####
    cp "${CASE}.in2" "${CASE}.in2_before_TEMP"

    awk '
    {
        if ($1 == "TETRA" || $1 == "GAUSS" || $1 == "TEMP") {
            print "TEMP    0.002"
        } else {
            print $0
        }
    }
    ' "${CASE}.in2_before_TEMP" > "${CASE}.in2"

    ##### step 12: show smearing line #####
    echo "Smearing line in ${CASE}.in2:"
    grep -n "TEMP\|TETRA\|GAUSS" "${CASE}.in2"

    ##### step 13: run SCF #####
    run_lapw -p -cc 0.00001 -ec 0.00001

    ##### step 14: print run info #####
    echo "total energy"
    grep ':ENE' "${CASE}.scf" | tail -1

    echo "Fermi energy"
    grep ':FER' "${CASE}.scf" | tail -1

    echo "RMT values"
    grep "RMT" "${CASE}.struct" || true

done

##### step 15: collect energies #####
OUT="$BASE_DIR/1_scf_PBE/energy_vs_d_PBE.dat"
rm -f "$OUT"

for D in $D_LIST; do
    SCF="$BASE_DIR/1_scf_PBE/d_${D}/$CASE/${CASE}.scf"

    if [ -f "$SCF" ]; then
        ENE=$(grep ':ENE' "$SCF" | tail -1 | awk '{print $NF}')
        echo "$D $ENE" >> "$OUT"
    else
        echo "WARNING: missing $SCF"
    fi
done

echo ""
echo "Saved PBE energies to:"
echo "$OUT"
