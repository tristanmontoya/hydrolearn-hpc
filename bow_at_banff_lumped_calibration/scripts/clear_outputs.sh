#!/usr/bin/env bash
set -euo pipefail

# Run cleanup relative to the case directory
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Remove generated SUMMA outputs and diagnostics
rm -f model/simulations/run1/SUMMA/*
rm -f results/KGE.txt results/obs_vs_sim.png results/streamflow_simulated.csv

# Remove generated OSTRICH calibration outputs
rm -rf output_archive/*
rm -rf ostrich_worker_*
rm -f Ost*.txt dds_status.out model_run.log slurm-*.out \
    strong_scaling_times_*.csv strong_scaling_summary_*.csv
rm -rf scaling_archive_*
