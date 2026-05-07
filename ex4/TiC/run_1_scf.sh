#!/usr/bin/env bash
set -e

CASE="TiC"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_DIR="$BASE_DIR/1_scf/$CASE"

##### step 1: make calculation directory #####
mkdir -p "$RUN_DIR"

##### step 2: copy struct file from top directory #####
cp "$BASE_DIR/${CASE}.struct" "$RUN_DIR/"

##### step 3: go into run directory #####
cd "$RUN_DIR"

##### step 4: run sgroup on copied struct #####
x sgroup

##### step 5: replace only the copied struct in run directory #####
if [ -f "${CASE}.struct_sgroup" ]; then
    cp "${CASE}.struct" "${CASE}.struct_before_sgroup"
    cp "${CASE}.struct_sgroup" "${CASE}.struct"
else
    echo "ERROR: ${CASE}.struct_sgroup was not created"
    exit 1
fi

##### step 6: initialize calculation #####
# 10,000 kpoints
init_lapw -numk 10000

##### step 7: run scf #####
# convergence criteria: charge/energy convergence 10e-5
run_lapw -cc 0.00005 -ec 0.00005

##### step8: generate potential using density of last cycle #####
x lapw0

######### run infor #########
echo "total energy"
echo | grep :ENE "$RUN_DIR/$CASE.scf"

echo "Fermi energy"
echo | grep :FER "$RUN_DIR/$CASE.scf"

#echo "total # e- in Ti sphere"
#echo | grep :CTO001 "$RUN_DIR/$CASE.scf"

#echo "total # e- in C sphere"
#echo | grep :CTO002 "$RUN_DIR/$CASE.scf"

echo "total # e- in interstitial region"
echo | grep :CTO "$RUN_DIR/$CASE.scf"







