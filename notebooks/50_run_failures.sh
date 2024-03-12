#!/bin/bash
#conda activate cdr_climate_uncertainty

while IFS=, read -r number model scenario i; 
do
    echo "Running iterations for ${model} ${scenario} ${i}"
    papermill 403_iterate_for_cdr.ipynb -p ENSEMBLE_MEMBER $i -p MODEL "$model" -p SCENARIO "$scenario" papermill_output/"403_${i}_${model}_${scenario}.ipynb"
done < ../data/501_rerun.csv

echo "Running batch 2"
while IFS=, read -r number model scenario i; 
do
    echo "Running iterations for ${model} ${scenario} ${i}"
    papermill 403_iterate_for_cdr.ipynb -p ENSEMBLE_MEMBER $i -p MODEL "$model" -p SCENARIO "$scenario" papermill_output/"403_${i}_${model}_${scenario}.ipynb"
done < ../data/502_rerun_batch2.csv
