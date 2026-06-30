#!/usr/bin/env bash
#SBATCH --job-name=parallel-calibration
#SBATCH --nodes=2
#SBATCH --ntasks=5
#SBATCH --ntasks-per-node=4
#SBATCH --time=08:00:00
#SBATCH --output=slurm-%x-%j.out
set -euo pipefail

# Prevent accidental execution on the login node
if [ -z "${SLURM_JOB_ID:-}" ]; then
    echo "Submit this script with sbatch instead of running it on the login node" >&2
    exit 1
fi

# Use the executables available on PATH
export PYTHON="${PYTHON:-python}"
export SUMMA_EXE="${SUMMA_EXE:-summa.exe}"
export PARALLEL_CALIBRATION_ROOT="${PWD}"

# Create a CSV file to store the strong scaling timings
job_id="${SLURM_JOB_ID:-local}"
timing_file="strong_scaling_times_${job_id}.csv"
summary_file="strong_scaling_summary_${job_id}.csv"
archive_root="scaling_archive_${job_id}"
printf "nworkers,ntasks,seconds\n" > "${timing_file}"
printf "nworkers,ntasks,seconds,best_kge,archive_dir\n" > "${summary_file}"
mkdir -p "${archive_root}"
cp -p ostIn.txt scripts/run_ostrich.sh "${archive_root}/"

# ParallelDDS uses one coordinator rank in addition to the worker ranks
for worker_count in 1 2 4; do
    task_count=$((worker_count + 1))
    run_archive="${archive_root}/workers_${worker_count}"
    export OUTPUT_ARCHIVE_DIR="${PWD}/${run_archive}/output_archive"

    # Remove any leftover runtime files from previous runs
    for runtime_path in ostrich_worker_* Ost*.txt model_run.log; do
        if [ -e "${runtime_path}" ]; then
            rm -rf -- "${runtime_path}"
        fi
    done

    # Start this worker-count run with a clean archive
    rm -rf -- "${run_archive}"
    mkdir -p "${OUTPUT_ARCHIVE_DIR}"

    # Run the parallel calibration with the current worker count
    echo "Running ParallelDDS with ${worker_count} worker(s) and ${task_count}" \
        "MPI task(s)"
    start_time="$(date +%s.%N)"
    srun --ntasks="${task_count}" OstrichMPI
    end_time="$(date +%s.%N)"

    # Calculate the elapsed time and write a line to the strong scaling CSV file
    elapsed_seconds="$(
        awk -v start_time="${start_time}" -v end_time="${end_time}" \
            'BEGIN { printf "%.2f", end_time - start_time }'
    )"
    printf "%s,%s,%s\n" "${worker_count}" "${task_count}" \
        "${elapsed_seconds}" >> "${timing_file}"

    # Preserve the best model and diagnostics from this worker-count run
    best_kge="NA"
    if [ -f "${OUTPUT_ARCHIVE_DIR}/KGE.txt" ]; then
        best_kge="$(awk 'NR == 1 { print $1 }' "${OUTPUT_ARCHIVE_DIR}/KGE.txt")"
    fi

    # Keep output_archive aligned with the latest completed run
    rm -rf -- output_archive
    cp -a "${OUTPUT_ARCHIVE_DIR}" output_archive

    cp -p "${timing_file}" "${summary_file}" "${run_archive}/"
    printf "%s,%s,%s,%s,%s\n" "${worker_count}" "${task_count}" \
        "${elapsed_seconds}" "${best_kge}" "${run_archive}" >> "${summary_file}"
done
