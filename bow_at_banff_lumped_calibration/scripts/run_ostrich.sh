#!/usr/bin/env bash
#SBATCH --job-name=parallel-calibration
#SBATCH --nodes=2
#SBATCH --ntasks=8
#SBATCH --ntasks-per-node=4
#SBATCH --time=08:00:00
#SBATCH --output=slurm-%x-%j.out
set -euo pipefail

# Use the executables available on PATH
export PYTHON="${PYTHON:-python}"
export SUMMA_EXE="${SUMMA_EXE:-summa.exe}"
export PARALLEL_CALIBRATION_ROOT="${PWD}"

# Create a CSV file to store the strong scaling timings
job_id="${SLURM_JOB_ID:-local}"
timing_file="strong_scaling_times_${job_id}.csv"
printf "ntasks,seconds\n" > "${timing_file}"

# Run the same calibration with increasing MPI task counts
for task_count in 1 2 4 8; do
    # Remove any leftover runtime files from previous runs
    for runtime_path in ostrich_worker_* Ost*.txt model_run.log; do
        if [ -e "${runtime_path}" ]; then
            rm -rf -- "${runtime_path}"
        fi
    done

    # Run the parallel calibration with the current task count
    echo "Running ParallelDDS with ${task_count} MPI task(s)"

    start_time="$(date +%s)"
    srun --ntasks="${task_count}" OstrichMPI
    end_time="$(date +%s)"

    # Calculate the elapsed time and write a line to the strong scaling CSV file
    elapsed_seconds=$((end_time - start_time))
    printf "%s,%s\n" "${task_count}" "${elapsed_seconds}" >> "${timing_file}"
done
