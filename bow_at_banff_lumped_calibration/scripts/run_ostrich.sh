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
    task_count=$((worker_count + 1))
    run_archive="${archive_root}/workers_${worker_count}"
    export OUTPUT_ARCHIVE_DIR="${PWD}/${run_archive}/output_archive"

    # Start this worker-count run from clean runtime and archive paths
    rm -rf ostrich_worker_* Ost*.txt model_run.log "${run_archive}"
    mkdir -p "${OUTPUT_ARCHIVE_DIR}"

    # Run the parallel calibration with the current worker count
    start_time="${SECONDS}"
    srun --ntasks="${task_count}" OstrichMPI

    # Calculate the elapsed time for this worker-count run
    elapsed_seconds=$((SECONDS - start_time))

    # Preserve the best model and diagnostics from this worker-count run
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
