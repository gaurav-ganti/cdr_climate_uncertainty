#!/bin/bash
#conda activate cdr_climate_uncertainty

echo "Running re-run batches"
while IFS=, read -r index i model scenario; 
do
    echo "Running iterations for ${model} ${scenario} ${i}"
    papermill 403_iterate_for_cdr.ipynb -p ENSEMBLE_MEMBER $i -p MODEL "$model" -p SCENARIO "$scenario" papermill_output/"403_${i}_aim_${scenario}.ipynb"
done < ../data/405_final.csv
