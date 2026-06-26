#!/usr/bin/env bash
set -euo pipefail

# Resolve paths from this cleanup script location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
basin_dir="$(cd "${script_dir}/.." && pwd -P)"

# Define generated output locations
summa_output_dir="${basin_dir}/model/simulations/run1/SUMMA"
results_dir="${basin_dir}/results"
output_archive="${basin_dir}/output_archive"

# Remove generated SUMMA outputs and diagnostics
rm -f "${summa_output_dir}"/*
rm -f \
    "${results_dir}/KGE.txt" \
    "${results_dir}/obs_vs_sim.png" \
    "${results_dir}/streamflow_simulated.csv"

# Remove generated OSTRICH calibration outputs
rm -rf "${output_archive}"/*
rm -rf "${basin_dir}"/ostrich_worker_*
rm -f \
    "${basin_dir}"/Ost*.txt \
    "${basin_dir}"/dds_status.out \
    "${basin_dir}"/model_run.log \
    "${basin_dir}"/slurm-*.out \
    "${basin_dir}"/strong_scaling_times_*.csv
