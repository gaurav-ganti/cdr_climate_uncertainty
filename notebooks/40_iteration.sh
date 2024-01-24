#!/bin/bash
#conda activate cdr_climate_uncertainty

echo "Making first guesses now"

jupyter execute 401_first_guess_lookup_metrics.ipynb

sleep 5

jupyter execute 402_first_guess_cdr_pathways.ipynb

echo "Starting with iterations"

END=$1

while IFS=, read -r number model scenario; 
do
    echo "Running iterations for ${model} ${scenario}"
    for i in $(seq 0 $END) 
    do
        papermill 403_iterate_for_cdr.ipynb -p ENSEMBLE_MEMBER ${i} -p MODEL "$model" -p SCENARIO "$scenario" papermill_output/"403_${i}_$model_$scenario.ipynb"
    done
done < ../data/100_scenario_names.csv
