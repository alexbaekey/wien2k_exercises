#!/usr/bin/env bash

set -e

CASE="TiC"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

##### step 1: recreate band structure directory #####
rm -rf "$BASE_DIR/2_bandstructure"
mkdir -p "$BASE_DIR/2_bandstructure"
cp -r "$BASE_DIR/1_scf/$CASE" "$BASE_DIR/2_bandstructure/"

##### step 2: go into case directory #####
cd "$BASE_DIR/2_bandstructure/$CASE"

##### step 3: generate k-path with XCrySDen #####
#/mnt/c/Users/alexa/Desktop/xcrysden-1.6.2-bin-shared/xcrysden
~/Desktop/ucf_research/PauloLab/ab_DFT_tutorial_Paulo/ex2/xcrysden-1.6.2/xcrysden

##### step 4: run band structure #####
x lapw1 -band

x lapw2 -band -qtl

x spaghetti -d

write_insp_lapw

#EF=$(grep ':FER' "$CASE.scf" | tail -1 | awk '{print $NF}')
#sed -i "s/x.xxxx/${EF}/" "$CASE.insp"

x spaghetti
