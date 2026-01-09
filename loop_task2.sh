#!/bin/bash

for i in 50 100 200 300 400 500 600 700 800 
do 
 cd "T=${i}"
 rm -rf store
 mkdir store
 cd store
 cp ../OUT.ABACUS/STRU/* .
 cp ../OUT.ABACUS/running_md.log .
 cp ../OUT.ABACUS/MD_dump .
 cp ../INPUT .
 cp ../../abacus2nep.sh .
 sh abacus2nep.sh .
 cd ../../
done
echo "all STRU files have been convert to extxyz format"

mkdir -p NEPdataset
cd NEPdataset
for i in 50 100 200 300 400 500 600 700 800 
do 
    cp ../"T=${i}"/store/NEPdataset/NEP-dataset.xyz "NEP-dataset_${i}.xyz"
    if [ "${i}" -ne 50 ]; then
        cat "NEP-dataset_${i}.xyz" >> NEP-dataset_50.xyz
    fi
done
cp NEP-dataset_50.xyz NEP-dataset.xyz
echo "all extxyz files have been added to NEP-dataset.xyz"
cd ..

python split.py