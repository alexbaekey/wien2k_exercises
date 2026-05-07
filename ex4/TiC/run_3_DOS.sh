#!/usr/bin/env bash

set -e

CASE="TiC"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

##### step 1: copy scf case directory #####
rm -rf "$BASE_DIR/3_DOS/$CASE"
mkdir -p "$BASE_DIR/3_DOS"
cp -r "$BASE_DIR/1_scf/$CASE" "$BASE_DIR/3_DOS/"

##### step 2: go into case directory #####
cd "$BASE_DIR/3_DOS/$CASE"

##### step 3: print fermi energy #####
grep ':FER' "$CASE.scf" | tail -1

##### step 4a. IMPORTANT: lapw2.def does not read TiC.vector from the case directory. 
##### It reads the vector file from scratch directory. 
##### Need to remove from scratch and rerun lapw
##### This was causing lapw2 errors like
##### double free or corruption (out) 
##### munmap_chunk(): invalid pointer

rm -f ~/wien2k_scratch/TiC.vector
x lapw1

##### step 4: generate qtl file #####
x lapw2 -qtl

##### step 5: create int file #####
configure_int_lapw

##### step 6: run tetra #####
x tetra
