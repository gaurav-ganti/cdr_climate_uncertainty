#!/bin/bash
#conda activate cdr_climate_uncertainty
ENS=$1

echo "Running MAGICC for ensemble members 0-${ENS}"
papermill 201_magicc7_input_scenarios.ipynb -p ENSEMBLE_MEMBERS ${ENS} papermill_output/"201_${ENS}.ipynb"
papermill 202_magicc7_netzero_scenarios.ipynb -p ENSEMBLE_MEMBERS ${ENS} papermill_output/"202_${ENS}.ipynb"

echo "Crunching metrics now.."

jupyter execute 301_calculate_co2_drawdown.ipynb 302_calculate_zec.ipynb 303_calculate_non_co2_contribution.ipynb

echo "Compiling metrics now.."

jupyter execute 304_compile_metrics.ipynb

echo "Done"