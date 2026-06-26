#!/usr/bin/env bash
set -euo pipefail

# Resolve paths from this cleanup script location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
basin_dir="$(cd "${script_dir}/.." && pwd -P)"

# Define generated output locations
summa_output_dir="${basin_dir}/model/simulations/run1/SUMMA"
route_output_dir="${basin_dir}/model/simulations/run1/mizuRoute"
results_dir="${basin_dir}/results"
log_file="${basin_dir}/model_run.log"

# Remove generated model outputs
rm -f "${summa_output_dir}"/*
rm -f "${route_output_dir}"/*

# Remove generated diagnostics and run log
rm -f \
    "${results_dir}/KGE.txt" \
    "${results_dir}/obs_vs_sim.png" \
    "${results_dir}/streamflow_simulated.csv" \
    "${log_file}"
