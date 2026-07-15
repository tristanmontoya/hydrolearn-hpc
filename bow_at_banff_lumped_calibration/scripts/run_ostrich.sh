#!/usr/bin/env bash
#SBATCH --job-name=bow-lumped-calib
#SBATCH --ntasks=8
#SBATCH --time=01:00:00
#SBATCH --output=slurm-%x-%j.out
set -euo pipefail

# Use the submission directory as the source case
case_dir="${SLURM_SUBMIT_DIR:-${PWD}}"

# Run each job in a separate copied case directory
run_dir="${case_dir}/scaling_archive_${SLURM_JOB_ID}"
mkdir -p "${run_dir}"
cp -R "${case_dir}/ostIn.txt" "${case_dir}/model" "${case_dir}/obs" \
    "${case_dir}/ostrich" "${case_dir}/scripts" "${run_dir}/"
cd "${run_dir}"

# Archive best models inside this job directory
export PARALLEL_CALIBRATION_ROOT="${PWD}"
export OUTPUT_ARCHIVE_DIR="${PWD}/output_archive"

# Run the parallel calibration with all allocated tasks
srun --ntasks="${SLURM_NTASKS}" OstrichMPI
