#!/usr/bin/env bash
#SBATCH --job-name=parallel-calibration
#SBATCH --nodes=2
#SBATCH --ntasks=5
#SBATCH --ntasks-per-node=4
#SBATCH --time=08:00:00
#SBATCH --output=slurm-%x-%j.out
set -euo pipefail

# Preserve best models in the original case directory
export PARALLEL_CALIBRATION_ROOT="${PWD}"

# Create a summary file for the scaling study
summary_file="strong_scaling_summary_${SLURM_JOB_ID}.csv"
archive_root="scaling_archive_${SLURM_JOB_ID}"
printf "nworkers,ntasks,seconds,best_kge,archive_dir\n" > "${summary_file}"
mkdir -p "${archive_root}"
cp ostIn.txt scripts/run_ostrich.sh "${archive_root}/"

# ParallelDDS uses one coordinator rank in addition to the worker ranks
for worker_count in 1 2 4; do
    # Calculate the total number of tasks needed for this worker count
    task_count=$((worker_count + 1))

    # Set the output archive directory for this worker-count run
    run_archive="${archive_root}/workers_${worker_count}"
    export OUTPUT_ARCHIVE_DIR="${PWD}/${run_archive}/output_archive"

    # Clean previous run artifacts
    rm -rf ostrich_worker_* Ost*.txt model_run.log "${run_archive}"

    # Make a fresh output archive directory
    mkdir -p "${OUTPUT_ARCHIVE_DIR}"

    # Start the timer for this worker-count run
    start_time="${SECONDS}"

    # Run the parallel calibration with the current worker count
    srun --ntasks="${task_count}" OstrichMPI

    # Calculate the elapsed time for this worker-count run
    elapsed_seconds=$((SECONDS - start_time))

    # Read the best KGE from the current run into the variable `best_kge`
    # or set `best_kge` to `NA` if the file does not exist
    best_kge="NA"
    if [ -f "${OUTPUT_ARCHIVE_DIR}/KGE.txt" ]; then
        read -r best_kge _ < "${OUTPUT_ARCHIVE_DIR}/KGE.txt"
    fi

    # Keep output_archive aligned with the latest completed run
    rm -rf output_archive
    cp -r "${OUTPUT_ARCHIVE_DIR}" output_archive

    printf "%s,%s,%s,%s,%s\n" "${worker_count}" "${task_count}" \
        "${elapsed_seconds}" "${best_kge}" "${run_archive}" >> "${summary_file}"
done
